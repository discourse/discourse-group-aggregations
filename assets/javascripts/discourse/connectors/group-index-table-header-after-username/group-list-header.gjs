import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import TableHeaderToggle from "discourse/components/table-header-toggle";

export default class GroupListHeader extends Component {
  @service site;
  @service router;

  @tracked group = this.args.outletArgs.group;
  @tracked order = this.args.outletArgs.order;
  @tracked asc = this.args.outletArgs.asc;

  aggregatedChildrenCount = this.group?.aggregated_children?.length || 0;

  constructor() {
    super(...arguments);

    if (this.aggregatedChildrenCount === 0) {
      return;
    }
    const table = document.querySelector(".group-members--can-manage");

    if (!table) {
      return;
    }

    table.classList.add("aggregate-group-members--can-manage");
    table.classList.remove("group-members--can-manage");
  }

  get isAggregate() {
    return this.aggregatedChildrenCount > 0;
  }

  <template>
    {{#if this.isAggregate}}
      <TableHeaderToggle
        @order={{this.order}}
        @asc={{this.asc}}
        @field="groups"
        @labelKey="groups.source_group"
        @automatic={{true}}
        class="directory-table__column-header--groups"
      />
    {{/if}}
  </template>
}
