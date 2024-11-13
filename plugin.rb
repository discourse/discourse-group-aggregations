# frozen_string_literal: true

# name: discourse-group-aggregations
# about: Aggregate groups
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :discourse_group_aggregations_enabled

register_asset "stylesheets/common.scss"

after_initialize do
  require_relative "lib/discourse_group_aggregations/engine"
  require_relative "lib/discourse_group_aggregations/group_extension"
  require_relative "app/jobs/regular/aggregate_group_memberships"
  require_relative "lib/discourse_group_aggregations/group_aggregator"

  # reloadable_patch do
    Group.prepend DiscourseGroupAggregations::GroupExtension

    add_model_callback(Group, :after_save) do
      ::Jobs.enqueue(:aggregate_group_memberships, group_id: self.id, action: "update")
    end

    on(:user_added_to_group) do |user, group, _automatic|
      if group.custom_fields["aggregated_children"].present? || group.aggregated_parents.present? # TODO here's where the issue comes from
        ::Jobs.enqueue(
          :aggregate_group_memberships,
          group_id: group.id,
          user_id: user.id,
          action: "add",
        )
      end
    end

    on(:user_removed_from_group) do |user, group|
      if group.custom_fields["aggregated_children"].present? || group.aggregated_parents.present?
        ::Jobs.enqueue(
          :aggregate_group_memberships,
          group_id: group.id,
          user_id: user.id,
          action: "remove",
        )
      end
    end

    register_group_custom_field_type("aggregated_children", :string)
    register_group_custom_field_type("groups_to_exclude", :string)
    register_group_custom_field_type("groups_to_exclude_retroactive", :boolean)
    register_group_custom_field_type("domains_to_exclude_from_group", :string)

    register_editable_group_custom_field("aggregated_children")
    register_editable_group_custom_field("groups_to_exclude")
    register_editable_group_custom_field("groups_to_exclude_retroactive")
    register_editable_group_custom_field("domains_to_exclude_from_group")

    add_preloaded_group_custom_field("aggregated_children")
    add_preloaded_group_custom_field("groups_to_exclude")
    add_preloaded_group_custom_field("groups_to_exclude_retroactive")
    add_preloaded_group_custom_field("domains_to_exclude_from_group")

    add_to_serializer(
      :group_show,
      :aggregated_parents,
      include_condition: -> { scope.is_admin? },
    ) { object.aggregated_parents.as_json(only: %i[id name]) }

    add_to_serializer(:group_user, :groups, include_condition: -> { scope.is_admin? }) do
      object
        .groups
        .order(:id)
        .visible_groups(scope.user)
        .members_visible_groups(scope.user)
        .as_json(only: %i[id name])
    end

    add_to_serializer(
      :group_show,
      :aggregated_children,
      include_condition: -> { scope.is_admin? },
    ) { object.custom_fields["aggregated_children"]&.split("|")&.map(&:to_i) }

    add_to_serializer(
      :group_show,
      :is_aggregated_group,
      include_condition: -> { scope.is_admin? },
    ) { object.is_aggregated_group? }

    add_to_serializer(
      :basic_group,
      :is_aggregated_group,
      include_condition: -> { scope.is_admin? },
    ) { object.is_aggregated_group? }
  
    add_to_serializer(:group_show, :groups_to_exclude, include_condition: -> { scope.is_admin? }) do
      object.custom_fields["groups_to_exclude"]&.split("|")&.map(&:to_i)
    end

    add_to_serializer(
      :group_show,
      :groups_to_exclude_retroactive,
      include_condition: -> { scope.is_admin? },
    ) { object.custom_fields["groups_to_exclude_retroactive"] }

    add_to_serializer(
      :group_show,
      :domains_to_exclude_from_group,
      include_condition: -> { scope.is_admin? },
    ) { object.custom_fields["domains_to_exclude_from_group"]&.split("|") }
  # end
end
