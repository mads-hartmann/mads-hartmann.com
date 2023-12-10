import ejs from "ejs";
import fs from "fs";
import path from "path";
import { marked } from "marked";

async function main() {
  const srcDir = "src";
  const pagesDir = `${srcDir}/pages`;

  const layoutPath = `${srcDir}/layout.ejs`;
  const layoutContent = await fs.promises.readFile(layoutPath, "utf8");
  const template = ejs.compile(layoutContent);

  const ps = await fs.promises.readdir(pagesDir);
  const pss = ps.map(async (filename) => {
    const filePath = path.join(pagesDir, filename);
    const markdown = await fs.promises.readFile(filePath, "utf8");
    const h = await marked.parse(markdown);
    const data = {
      title: "test",
      content: h,
    };
    const html = template(data);
    console.log(html);
    return html;
  });
  await Promise.all(pss);
}

await main();
