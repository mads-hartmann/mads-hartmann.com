import { Client } from "@notionhq/client";
import { NotionToMarkdown } from "notion-to-md";
import { marked } from "marked";
import { gfmHeadingId } from "marked-gfm-heading-id";

const header = `
---
title: ~ v3
---

<!--
    DO NOT EDIT
    This has been generated by a script. Any changes you make will be overwritten.
-->
`.trim();

async function main() {
  const notion = new Client({
    auth: process.env.NOTION_TOKEN,
  });

  const n2m = new NotionToMarkdown({
    notionClient: notion,
    config: {
      separateChildPage: true,
    },
  });

  const mdBlocks = await n2m.pageToMarkdown("9c3cf9a818da426f9be44d838395396c");
  const mdString = n2m.toMarkdownString(mdBlocks);
  marked.use(
    gfmHeadingId({
      prefix: "heading-",
    })
  );
  const html = await marked.parse(mdString.parent);
  console.log(header);
  console.log(colspan(html));
}

// Hack to add colspan to table
function colspan(html) {
  return html
    .replaceAll("<td><strong>", `<td colspan="4"><strong>`)
    .replaceAll(`</td>\n<td></td>\n<td></td>`, "</td>");
}

await main();
