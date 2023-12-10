import ejs from "ejs";
import fs from "fs";
import fsExtra from "fs-extra";
import path from "path";
import { marked } from "marked";
import matter from "gray-matter";

async function main() {
  const srcDir = "src";
  const distDir = "_site";
  const pagesDir = `${srcDir}/pages`;

  const layoutPath = `${srcDir}/layout.ejs`;
  const layoutContent = await fs.promises.readFile(layoutPath, "utf8");
  const template = ejs.compile(layoutContent);

  await fs.promises.mkdir(distDir, { recursive: true });
  await fsExtra.copy(`${srcDir}/css`, `${distDir}/css`);

  const ps = await fs.promises.readdir(pagesDir);
  const pss = ps.map(async (filename) => {
    const filePath = path.join(pagesDir, filename);
    const markdown = await fs.promises.readFile(filePath, "utf8");
    const { data, content } = matter(markdown);
    const h = await marked.parse(content);
    const html = template({
      title: data.title,
      content: h,
    });
    const destination = `${distDir}/${filename.replace(".md", ".html")}`;
    await fs.promises.writeFile(destination, html);
    console.log("wrote ", destination);
  });
  await Promise.all(pss);
}

await main();
