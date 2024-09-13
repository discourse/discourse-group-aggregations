# frozen_string_literal: true

require "rails_helper"
require_relative "./../../../lib/discourse_group_aggregations/group_aggregator"

RSpec.describe DiscourseGroupAggregations::GroupAggregator do
  fab!(:group)
  fab!(:child_group) { Fabricate(:group) }
  fab!(:excluded_group) { Fabricate(:group) }
  fab!(:user_in_child_group) { Fabricate(:user) }
  fab!(:user_in_excluded_group) { Fabricate(:user) }
  fab!(:user_with_excluded_domain) { Fabricate(:user, email: "user@excluded.com") }
  let(:aggregator) { described_class.new(group) }

  before do
    SiteSetting.discourse_group_aggregations_enabled = true
    child_group.add(user_in_child_group)
    excluded_group.add(user_in_excluded_group)

    group.custom_fields["aggregated_children"] = child_group.id.to_s
    group.custom_fields["groups_to_exclude"] = excluded_group.id.to_s
    group.custom_fields["domains_to_exclude_from_group"] = "excluded.com"
    group.save
  end

  describe "#aggregate" do
    it "aggregates users from child groups to the parent group" do
      aggregator.aggregate
      expect(group.reload.users).to include(user_in_child_group)
    end

    it "excludes users from specified groups" do
      aggregator.aggregate
      expect(group.reload.users).not_to include(user_in_excluded_group)
    end

    it "excludes users with specified email domains" do
      child_group.add(user_with_excluded_domain)
      aggregator.aggregate
      expect(group.reload.users).not_to include(user_with_excluded_domain)
    end

    it "removes users from the parent group when they are no longer part of any child groups" do
      aggregator.aggregate
      expect(group.reload.users).to include(user_in_child_group)

      group.custom_fields["aggregated_children"] = ""
      group.save
      aggregator.aggregate
      expect(group.reload.users).not_to include(user_in_child_group)
    end

    it "does nothing when the plugin is disabled" do
      SiteSetting.discourse_group_aggregations_enabled = false
      group.expects(:add).never
      group.expects(:remove).never
      aggregator.aggregate
    end
  end

  describe "#handle_everyone_group_as_source" do
    fab!(:main_group) { Fabricate(:group) }
    let(:everyone_group_aggregator) { described_class.new(main_group) }

    before do
      main_group.custom_fields["aggregated_children"] = Group::AUTO_GROUPS[:everyone].to_s
      main_group.save
    end

    it "includes all users except those in the excluded group" do
      all_users = Fabricate.times(3, :user) # Create 3 users to represent all users in the system
      everyone_group_aggregator.aggregate

      expect(main_group.reload.users).to include(*all_users).and include(user_in_excluded_group)

      main_group.custom_fields["groups_to_exclude"] = excluded_group.id.to_s
      main_group.save
      everyone_group_aggregator.aggregate

      expect(main_group.reload.users).not_to include(user_in_excluded_group)
      expect(main_group.reload.users).to include(*all_users)
    end
  end

  describe "#aggregate_parents" do
    fab!(:parent_group) { Fabricate(:group) }

    before do
      group.custom_fields["aggregated_children"] = child_group.id.to_s
      group.save
    end

    it "aggregates users to parent groups when users are added to child groups" do
      new_user = Fabricate(:user)
      child_group.add(new_user)

      child_group.save

      aggregator.aggregate

      expect(group.reload.users).to include(new_user)
    end
  end

  describe "#aggregate_user" do
    it "adds the user to the parent group if they are part of a child group" do
      aggregator = described_class.new(group, user_in_child_group.id)
      aggregator.aggregate
      expect(group.reload.users).to include(user_in_child_group)
    end

    it "removes the user from the parent group if they are not part of any child group" do
      aggregator = described_class.new(group, user_in_child_group.id)
      aggregator.aggregate
      expect(group.reload.users).to include(user_in_child_group)

      child_group.remove(user_in_child_group)
      aggregator.aggregate
      expect(group.reload.users).not_to include(user_in_child_group)
    end

    it "excludes the user from the parent group if they belong to an excluded group" do
      aggregator = described_class.new(group, user_in_excluded_group.id)
      aggregator.aggregate
      expect(group.reload.users).not_to include(user_in_excluded_group)
    end

    it "excludes the user from the parent group if their email domain is excluded" do
      child_group.add(user_with_excluded_domain)
      aggregator = described_class.new(group, user_with_excluded_domain.id)
      aggregator.aggregate
      expect(group.reload.users).not_to include(user_with_excluded_domain)
    end
  end
end
