# frozen_string_literal: true
module DiscourseGroupAggregations
  class GroupAggregator
    ACTION_UPDATE = "update"
    ACTION_ADD = "add"
    ACTION_REMOVE = "remove"

    def initialize(group, user_id = nil)
      @group = group
      @user_id = user_id
    end

    def aggregate(action = nil)
      ActiveRecord::Base.transaction do
        return if SiteSetting.discourse_group_aggregations_enabled == false

        if @user_id && [ACTION_ADD, ACTION_REMOVE].include?(action)
          aggregate_user(action)
        else
          aggregate_children(@group)
        end

        aggregate_parents if @group.aggregated_parents.present?

        if @user_id
          @group.groups_excluding_this_group.each do |group|
            # update exclusions
            if group.custom_fields["aggregated_children"].present? ||
                 group.aggregated_parents.present?
              ::Jobs.enqueue(
                :aggregate_group_memberships,
                group_id: group.id,
                user_id: @user_id,
                action: "update",
              )
            end
          end
        end
      rescue => e
        Rails.logger.error("Error during aggregation: #{e.message}")
        raise ActiveRecord::Rollback
      end
    end

    private

    def aggregate_children(aggregating_group)
      source_groups = aggregating_group.aggregated_children

      # If there are no source groups, remove all users from the aggregating group
      if source_groups.empty?
        aggregating_group.users.clear
        return
      end

      if source_groups.any? { |group| group.id == Group::AUTO_GROUPS[:everyone] }
        handle_everyone_group_as_source(aggregating_group)
      else
        # Get users from all source groups
        source_group_users = source_groups.flat_map(&:users).uniq

        # Get excluded users from exclusion groups and domains
        excluded_users = get_excluded_users(aggregating_group, source_group_users)

        # Remove excluded users from the list of users to be aggregated
        users_to_aggregate = source_group_users - excluded_users

        existing_users = aggregating_group.users.to_a

        # Remove users from aggregating group who are not part of any source groups or are excluded
        remove_unrelated_users(aggregating_group, existing_users, users_to_aggregate)

        # Add users from source groups to the aggregating group, excluding the excluded ones
        add_new_users(aggregating_group, users_to_aggregate, existing_users)
      end
    end

    def handle_everyone_group_as_source(aggregating_group)
      # Get all user IDs in the system
      all_user_ids = User.pluck(:id)

      # Get excluded users from exclusion groups
      excluded_users = get_excluded_users(aggregating_group, all_user_ids)

      # Calculate the users to be added to the aggregating group (all users minus excluded)
      users_to_aggregate = all_user_ids - excluded_users.map(&:id)

      existing_users = aggregating_group.users.pluck(:id)

      # Calculate new users to add to the group
      new_user_ids = users_to_aggregate - existing_users

      # Bulk insert new users into the group if there are new users to add
      unless new_user_ids.empty?
        GroupUser.insert_all(
          new_user_ids.map do |user_id|
            {
              group_id: aggregating_group.id,
              user_id: user_id,
              created_at: Time.now,
              updated_at: Time.now,
            }
          end,
        )
      end

      # Remove users who are in the exclusion groups from the aggregating group
      users_to_remove = aggregating_group.users.where(id: excluded_users.map(&:id))
      users_to_remove.each { |user| aggregating_group.remove(user) }
    end

    def remove_unrelated_users(aggregating_group, existing_users, users_to_aggregate)
      users_to_remove = existing_users.reject { |user| users_to_aggregate.include?(user) }
      users_to_remove.each { |user| aggregating_group.remove(user) }
    end

    def add_new_users(aggregating_group, users_to_aggregate, existing_users)
      new_user_ids = users_to_aggregate.map(&:id) - existing_users.map(&:id)
      return if new_user_ids.empty?

      GroupUser.insert_all(
        new_user_ids.map do |user_id|
          {
            group_id: aggregating_group.id,
            user_id: user_id,
            created_at: Time.now,
            updated_at: Time.now,
          }
        end,
      )
    end

    def aggregate_user(action)
      user = User.find(@user_id)
      parent_groups = @group.aggregated_parents
      parent_groups.each do |parent_group|
        source_groups = parent_group.aggregated_children
        source_group_users = source_groups.flat_map(&:users).uniq
        excluded_users = get_excluded_users(parent_group, source_group_users)

        if action == ACTION_ADD
          handle_add_user_to_parent_group(user, parent_group, source_groups, excluded_users)
        elsif action == ACTION_REMOVE
          handle_remove_user_from_parent_group(user, parent_group, source_groups, excluded_users)
        end
      end
    end

    def handle_add_user_to_parent_group(user, parent_group, source_groups, excluded_users)
      return if excluded_users.include?(user)

      if source_groups.any? { |child_group| child_group.users.include?(user) }
        parent_group.add(user, automatic: true)
      end
    end

    def handle_remove_user_from_parent_group(user, parent_group, source_groups, excluded_users)
      if excluded_users.include?(user) ||
           !source_groups.any? { |child_group| child_group.users.include?(user) }
        parent_group.remove(user)
      end
    end

    def aggregate_parents
      parent_groups = @group.aggregated_parents

      return if parent_groups.empty?

      children_users = @group.aggregated_children.flat_map(&:users).uniq
      excluded_users = excluded_groups_users(@group)

      parent_groups.each do |parent|
        # Add all children users to the parent group
        children_users.each { |user| parent.add(user, automatic: true) }

        # Remove excluded users from the parent group
        excluded_users.each { |user| parent.remove(user) if parent.users.include?(user) }

        # Remove users with excluded domains from the parent group
        if parent.custom_fields["domains_to_exclude_from_group"].present?
          excluded_domains = parent.custom_fields["domains_to_exclude_from_group"].split("|")
          parent.users.each do |user|
            next if excluded_domains.exclude?(user.email.split("@").last)
            parent.remove(user)
          end
        end

        # Retroactively remove excluded users if the setting is enabled
        if parent.custom_fields["groups_to_exclude_retroactive"] == "t"
          excluded_users.each { |user| parent.remove(user) if parent.users.include?(user) }
        end
      end
    end

    def excluded_groups_users(group)
      excluded_groups_ids = group.custom_fields["groups_to_exclude"]&.split("|")
      return [] unless excluded_groups_ids

      Group.where(id: excluded_groups_ids).map(&:users).flatten.uniq
    end

    def excluded_domains_users(users, group)
      excluded_domains = group.custom_fields["domains_to_exclude_from_group"]&.split("|")
      return [] unless excluded_domains

      users.select { |user| excluded_domains.include?(user.email.split("@").last) }
    end

    def get_excluded_users(aggregating_group, source_group_users)
      excluded_users =
        excluded_groups_users(aggregating_group) +
          excluded_domains_users(source_group_users, aggregating_group)
      excluded_users.uniq
    end
  end
end
