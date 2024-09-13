import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";

export default class GroupInfo extends Component {
  static shouldRender(outletArgs) {
    if (!outletArgs.group || outletArgs.group.length === 0) {
      return false;
    }
  }
  @service site;
  @service router;
  @tracked model;

  constructor() {
    super(...arguments);
  }

  get excludedGroups() {
    return this.site.groups.filter((group) =>
      this.args.outletArgs.group.groups_to_exclude?.includes(group.id)
    );
  }

  get aggregatedChildren() {
    return this.site.groups.filter((group) =>
      this.args.outletArgs.group.aggregated_children?.includes(group.id)
    );
  }

  get aggregatedParents() {
    return this.args.outletArgs.group.aggregated_parents;
  }

  <template>
    <div>
      {{#if this.aggregatedChildren}}
        Aggregated From:
        <ul>
          {{#each this.aggregatedChildren as |group|}}
            <li>
              <LinkTo @route="group.manage" @model={{group.name}}>
                {{group.name}}
              </LinkTo>
            </li>
          {{/each}}
        </ul>
        <br />
      {{/if}}

      {{#if this.aggregatedParents}}
        Aggregates:
        <ul>
          {{#each this.aggregatedParents as |group|}}
            <li>
              <LinkTo @route="group.manage" @model={{group.name}}>
                {{group.name}}
              </LinkTo>
            </li>
          {{/each}}
        </ul>
        <br />
      {{/if}}

      {{#if this.excludedGroups}}
        Excluded Groups:
        <ul>
          {{#each this.excludedGroups as |group|}}
            <li>
              <LinkTo @route="group.manage" @model={{group.name}}>
                {{group.name}}
              </LinkTo>
            </li>
          {{/each}}
        </ul>
        <br />
      {{/if}}
    </div>
  </template>
}
