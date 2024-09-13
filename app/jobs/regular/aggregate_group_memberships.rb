# frozen_string_literal: true

module Jobs
  class AggregateGroupMemberships < ::Jobs::Base
    def execute(args)
      return if SiteSetting.discourse_group_aggregations_enabled == false
      group_id = args[:group_id]
      user_id = args[:user_id]
      action = args[:action]
      group = Group.find_by(id: group_id)

      return unless group

      DiscourseGroupAggregations::GroupAggregator.new(group, user_id).aggregate(action)
    end
  end
end
