// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// https://astro.build/config
export default defineConfig({
  integrations: [
    starlight({
      title: "宏哥的 WoW 世界",
      social: {
        github: "https://github.com/yangjh-xbmu/wowbook",
      },
      sidebar: [
        {
          label: "任务",
          autogenerate: { directory: "quest" },
          collapsed: true,
        },
      ],
    }),
  ],
});
