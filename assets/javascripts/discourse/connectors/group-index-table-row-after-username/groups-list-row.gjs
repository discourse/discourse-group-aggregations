import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { inject as service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";

export default class GroupsListRow extends Component {
  @service site;
  @service router;

  @controller("group") groupController;
  @tracked model = this.groupController?.model;

  constructor() {
    super(...arguments);
  }

  get groups() {
    if (!this.model.aggregated_children) {
      return;
    }
    const aggregatedChildrenIds = this.model.aggregated_children;

    return this.args.outletArgs.member.groups
      .filter((group) => aggregatedChildrenIds.includes(group.id))
      .map((group) => group.name)
      .join(", ");
  }

  get isAggregated() {
    return this.model.aggregated_children?.length > 0;
  }

  <template>
    {{#if this.isAggregated}}
      <div class="directory-table__cell directory-table__cell--groups">
        <span class="directory-table__label">
          <span>{{i18n "groups.member_added"}}</span>
        </span>
        <span class="directory-table__value">
          {{this.groups}}
        </span>
      </div>
    {{/if}}
  </template>
}
