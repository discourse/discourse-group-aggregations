# frozen_string_literal: true

module DiscourseGroupAggregations
  module GroupExtension
    extend ActiveSupport::Concern

    prepended do
      def aggregated_parents
        Group
          .joins("INNER JOIN group_custom_fields ON group_custom_fields.group_id = groups.id")
          .where("group_custom_fields.name = 'aggregated_children'")
          .where("group_custom_fields.value ~ ?", "(^|\\|)#{self.id}(\\||$)")
          .distinct
      end

      def groups_excluding_this_group
        Group
          .joins("INNER JOIN group_custom_fields ON group_custom_fields.group_id = groups.id")
          .where("group_custom_fields.name = 'groups_to_exclude'")
          .where("group_custom_fields.value ~ ?", "(^|\\|)#{self.id}(\\||$)")
          .distinct
      end

      def is_aggregated_group?
        custom_fields["aggregated_children"].present?
      end

      def aggregated_children
        children_ids = custom_fields["aggregated_children"]&.split("|")
        return [] if children_ids.blank?

        Group.where(id: children_ids)
      end
    end
  end
end
