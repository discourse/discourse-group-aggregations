import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { withPluginApi } from "discourse/lib/plugin-api";
import I18n from "discourse-i18n";

const PLUGIN_ID = "discourse-group-aggregations";

export default {
  name: "discourse-group-aggregations",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const groupController = container.lookup("controller:group");

    if (
      !groupController ||
      !siteSettings.discourse_group_aggregations_enabled
    ) {
      return;
    }
    withPluginApi("0.12.1", (api) => {
      api.modifyClass(
        "component:group-member-dropdown",
        (Superclass) =>
          class extends Superclass {
            get content() {
              if (!groupController?.model?.is_aggregated_group) {
                return super.content;
              }

              return super.content.filter((item) => item.id !== "removeMember");
            }
          }
      );

      api.modifyClass(
        "component:group-manage-save-button",
        (Superclass) =>
          class extends Superclass {
            @service dialog;
            @service site;
            @service router;

            @action
            Refresh() {
              super.save();
              window.location.reload();
            }

            @action
            save() {
              const group = this.model;

              if (
                group.hadAggregatedChildren &&
                !group?.aggregated_children?.length
              ) {
                // is removing all aggregations?
                this.dialog.yesNoConfirm({
                  message: I18n.t("groups.save_remove_aggregations_warning"),
                  didConfirm: this.Refresh,
                });
              } else if (group?.aggregated_children?.length) {
                this.dialog.yesNoConfirm({
                  message: I18n.t("groups.save_aggregation_warning"),
                  didConfirm: this.Refresh,
                });
              } else {
                super.save();
              }
            }
          }
      );

      api.onPageChange((url) => {
        const groupModel = groupController.model;

        if (!groupModel || !url.includes("/g/")) {
          return;
        }

        if (!groupModel.is_aggregated_group) {
          return;
        }
        const icon = `<svg class="fa d-icon d-icon-bullseye svg-icon prefix-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#bullseye"></use></svg>`;
        const manageGroupSelector = document.querySelector(
          ".group-members-manage"
        );
        if (manageGroupSelector) {
          manageGroupSelector.innerHTML = `<span class="text">You can't manage individual users in aggregated groups ${icon}</span>`;
        }

        const groupNamePanel = document.querySelector(".group-info-name");
        if (
          groupNamePanel &&
          !groupNamePanel.querySelector(".d-icon-bullseye")
        ) {
          groupNamePanel.insertAdjacentHTML("afterbegin", `${icon} `);
        }
      });
      api.modifyClass("model:group", {
        pluginId: PLUGIN_ID,

        asJSON() {
          return Object.assign({}, this._super(...arguments), {
            custom_fields: {
              aggregated_children: this.aggregated_children?.join("|"),
              groups_to_exclude: this.groups_to_exclude?.join("|"),
              groups_to_exclude_retroactive: this.groups_to_exclude_retroactive,
              domains_to_exclude_from_group:
                this.domains_to_exclude_from_group?.join("|"),
            },
          });
        },
      });
    });
  },
};
