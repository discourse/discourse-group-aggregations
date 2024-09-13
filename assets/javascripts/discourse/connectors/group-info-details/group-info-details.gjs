import { or } from "truth-helpers";

const GroupsInfo = <template>
  <span class="group-info-details">
    <span class="groups-info-name">
      <div class="large-font-icon">{{#if
          @outletArgs.group.is_aggregated_group
        }}<svg
            class="fa d-icon d-icon-bullseye svg-icon prefix-icon svg-string"
            xmlns="http://www.w3.org/2000/svg"
          ><use href="#bullseye"></use></svg>{{/if}}</div>
      {{or @outletArgs.group.full_name @outletArgs.group.displayName}}
    </span>
  </span>
</template>;

export default GroupsInfo;
