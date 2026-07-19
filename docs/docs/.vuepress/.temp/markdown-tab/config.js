import { CodeTabs } from "/Users/qianxunclub/workspace/mouse-dance/docs/node_modules/.pnpm/@vuepress+plugin-markdown-tab@2.0.0-rc.86_markdown-it@14.3.0_vuepress@2.0.0-rc.20_@vuep_6117de1e294b0ceac0beec9ec57061b2/node_modules/@vuepress/plugin-markdown-tab/lib/client/components/CodeTabs.js";
import { Tabs } from "/Users/qianxunclub/workspace/mouse-dance/docs/node_modules/.pnpm/@vuepress+plugin-markdown-tab@2.0.0-rc.86_markdown-it@14.3.0_vuepress@2.0.0-rc.20_@vuep_6117de1e294b0ceac0beec9ec57061b2/node_modules/@vuepress/plugin-markdown-tab/lib/client/components/Tabs.js";
import "/Users/qianxunclub/workspace/mouse-dance/docs/node_modules/.pnpm/@vuepress+plugin-markdown-tab@2.0.0-rc.86_markdown-it@14.3.0_vuepress@2.0.0-rc.20_@vuep_6117de1e294b0ceac0beec9ec57061b2/node_modules/@vuepress/plugin-markdown-tab/lib/client/styles/vars.css";

export default {
  enhance: ({ app }) => {
    app.component("CodeTabs", CodeTabs);
    app.component("Tabs", Tabs);
  },
};
