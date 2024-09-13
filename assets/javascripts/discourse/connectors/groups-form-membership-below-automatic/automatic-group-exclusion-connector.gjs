import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import ListSetting from "select-kit/components/list-setting";

export default class AutomaticGroupExclusionConnector extends Component {
  @service site;
  @controller("group-manage") groupManageController;
  @controller("groups-new") groupsNewController;
  @tracked controller;
  @tracked groupModel;

  @tracked aggregatedChildren = new TrackedArray();
  @tracked groupsToExclude = new TrackedArray();

  constructor() {
    super(...arguments);
    this.controller = this.groupManageController.model
      ? this.groupManageController
      : this.groupsNewController;
    this.groupModel = this.controller?.model;

    if (this.groupManageController.model.aggregated_children?.length > 0) {
      this.groupManageController.model.hadAggregatedChildren = true;
    }

    this.aggregatedChildren = new TrackedArray(
      this.controller.model.aggregated_children || []
    );
    this.groupsToExclude = new TrackedArray(
      this.controller.model.groups_to_exclude || []
    );
  }

  get IsAggregatingOtherGroups() {
    return (this.groupModel?.aggregated_parents?.length || 0) > 0;
  }

  get groupsForAggregation() {
    return this.site.groups
      .filter((group) => !group.is_aggregated_group)
      .filter((group) => group.name !== this.controller.model.name)
      .filter((group) => !this.groupsToExclude.includes(group.id));
  }

  get groupsForExclusion() {
    return this.site.groups
      .filter((group) => !group.is_aggregated_group)
      .filter((group) => !this.aggregatedChildren.includes(group.id));
  }

  get shouldShowExclusion() {
    return this.aggregatedChildren.length > 0;
  }

  @action
  handleGroupChange(newAggregatedGroups) {
    if (
      !this.aggregatedChildren.includes(0) &&
      newAggregatedGroups?.includes(0)
    ) {
      // everyone
      this.aggregatedChildren = new TrackedArray([0]);
      this.controller.model.aggregated_children = this.aggregatedChildren;
      return;
    }

    this.aggregatedChildren = new TrackedArray(
      [...newAggregatedGroups].filter((group) => group !== 0)
    );
    this.controller.model.aggregated_children = this.aggregatedChildren;
  }

  @action
  handleExclusionChange(newExcludedGroups) {
    this.groupsToExclude = new TrackedArray([...newExcludedGroups]);
    this.controller.model.groups_to_exclude = this.groupsToExclude;
  }

  <template>
    <hr />

    {{#if this.IsAggregatingOtherGroups}}
      <div class="control-group">
        <label class="control-label">Aggregate Membership Groups</label>
        <div>You cannot aggregate groups that are already aggregating other
          groups.</div>

        <div>Groups that this group aggregates include:</div>
        <ul>
          {{#each this.groupModel.aggregated_parents as |group|}}
            <li>
              <LinkTo @route="group.manage" @model={{group.name}}>
                {{group.name}}
              </LinkTo>
            </li>
          {{/each}}
        </ul>

      </div>
    {{else}}
      <div class="control-group">
        <label class="control-label">Aggregate Membership Groups</label>
        <label>Select the groups whose members will be included in this
          aggregate group's membership. Members of these groups will
          automatically become members of this aggregate group.</label>
        <ListSetting
          @name="aggregate_membership_groups"
          @value={{this.aggregatedChildren}}
          @choices={{this.groupsForAggregation}}
          @settingName="name"
          @nameProperty="name"
          @valueProperty="id"
          @onChange={{this.handleGroupChange}}
          class="group-form-automatic-membership-associated-groups"
        />
      </div>

      {{#if this.shouldShowExclusion}}
        <div class="control-group">
          <label class="control-label">Exclude from this aggregation</label>
          <label>Select the groups that should be excluded from this aggregate
            group's membership. Members of these groups will not be included in
            this aggregate group.</label>
          <ListSetting
            @name="automatic_membership_exclusion_groups"
            @value={{this.groupsToExclude}}
            @choices={{this.groupsForExclusion}}
            @settingName="name"
            @nameProperty="name"
            @valueProperty="id"
            @onChange={{this.handleExclusionChange}}
            class="group-form-automatic-membership-associated-groups"
          />
        </div>

        <div class="control-group">
          <label class="control-label">Exclusion Domains</label>
          <label>Specify domains whose members should be excluded from this
            aggregate group's membership.</label>
          <ListSetting
            @name="automatic_membership_exclusion_domains"
            @value={{this.controller.model.domains_to_exclude_from_group}}
            @choices={{this.controller.model.domains_to_exclude_from_group}}
            @settingName="name"
            @options={{hash allowAny=true}}
            class="group-form-automatic-membership-automatic"
          />
        </div>
      {{/if}}

    {{/if}}

    <hr />
  </template>
}
