import { copyFile, readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';
import { renderFooter } from '../shared/footer/render.mjs';
const root = fileURLToPath(new URL('.', import.meta.url));
const destination = process.argv[2] || `${root}dist`;
const markdown = await readFile(`${root}index.md`, 'utf8');
const tokens = marked.lexer(markdown);
const introduction = [];
const sections = [];
for (const token of tokens) {
  if (token.type === 'heading' && token.depth === 2) {
    sections.push({
      title: token.text,
      id: token.text.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
      heading: token,
      tokens: [],
    });
  } else if (sections.length) sections.at(-1).tokens.push(token);
  else introduction.push(token);
}
// Keep document-level reference links available when rendering each section.
const render = part => marked.parser(Object.assign(part, { links: tokens.links }));
const escape = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('"', '&quot;');
const contents = `<nav class="contents" aria-label="On this page">${sections.map(section =>
  `<a href="#${section.id}">${escape(section.title)}</a>`
).join('\n')}</nav>`;
const html = sections.map(section => {
  const heading = render([section.heading]).replace('<h2>', `<h2 id="${section.id}-heading">`);
  return `<section id="${section.id}" aria-labelledby="${section.id}-heading">${heading}<div class="section-content">${render(section.tokens)}</div></section>`;
}).join('\n');
await mkdir(destination, { recursive: true });
await writeFile(`${destination}/index.html`, `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Uses — Mads Hartmann</title><meta name="description" content="The hardware, software and equipment I use.">
<link rel="canonical" href="https://uses.mads-hartmann.com/">
<link rel="alternate" type="text/markdown" href="https://uses.mads-hartmann.com/index.md">
<link rel="describedby" type="text/plain" href="https://uses.mads-hartmann.com/llms.txt">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#f7f9fc" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#191d24" media="(prefers-color-scheme: dark)">
<style>
:root {
  color-scheme: light;
  --mh-footer-width: 952px;
  --mh-color-surface: #f7f9fc;
  --mh-color-text: #243247;
  --mh-color-muted: #596b80;
  --mh-color-border: #dbe2eb;
  --mh-color-accent: #305e91;
  --mh-color-accent-hover: #203f62;
}
@media screen and (prefers-color-scheme: dark) {
  :root {
    color-scheme: dark;
    --mh-color-surface: #191d24;
    --mh-color-text: #e6e8ed;
    --mh-color-muted: #a8b1c0;
    --mh-color-border: #343b47;
    --mh-color-accent: #edb978;
    --mh-color-accent-hover: #ffdab0;
  }
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body { margin: 0; background: var(--mh-color-surface); color: var(--mh-color-text); font: 18px/1.65 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
main { max-width: 1000px; margin: 0 auto; padding: 64px 24px 0; }
a { color: var(--mh-color-accent); text-underline-offset: 4px; text-decoration-thickness: 1px; }
a:hover { color: var(--mh-color-accent-hover); text-decoration-thickness: 2px; }
a:focus-visible { outline: 2px solid var(--mh-color-accent); outline-offset: 4px; }
.skip-link { position: absolute; top: -100px; left: 24px; padding: 10px; background: var(--mh-color-surface); }
.skip-link:focus { top: 12px; }
.intro { margin-bottom: 32px; }
h1 { font-size: 2rem; line-height: 1.2; letter-spacing: -.04em; margin: 0 0 24px; }
.intro p { max-width: 650px; }
p { margin: 0 0 20px; }
.contents { display: flex; flex-wrap: wrap; gap: 4px 26px; border-block: 1px solid var(--mh-color-border); padding: 8px 0; margin-bottom: 40px; }
.contents a { display: inline-flex; align-items: center; min-height: 44px; font-size: 14px; text-decoration: none; }
.contents a:hover { text-decoration: underline; }
section { display: grid; grid-template-columns: 175px minmax(0, 1fr); gap: 25px; padding: 32px 0; border-top: 1px solid var(--mh-color-border); scroll-margin-top: 24px; }
section:first-child { border-top: 0; padding-top: 0; }
section:last-child { padding-bottom: 0; }
h2 { margin: 0; font-size: 1.1rem; }
.section-content { min-width: 0; overflow-wrap: anywhere; }
.section-content > :first-child { margin-top: 0; }
.section-content > :last-child { margin-bottom: 0; }
h3 { font-size: 17px; font-weight: 600; line-height: 1.4; margin: 28px 0 14px; }
ul { margin: 0; padding-left: 18px; }
li { padding-left: 4px; margin-bottom: 12px; }
li:last-child { margin-bottom: 0; }
li::marker { color: var(--mh-color-muted); font-size: 11px; }
ul + p { margin-top: 24px; }
.back-to-top { margin: 36px 0 0; text-align: right; font-size: 13px; }
.back-to-top a { display: inline-flex; align-items: center; min-height: 44px; }
@media (max-width: 700px) {
  main { padding-top: 36px; }
  .contents { gap: 0 20px; margin-bottom: 30px; }
  .contents a { font-size: 13px; }
  section { grid-template-columns: minmax(0, 1fr); gap: 20px; padding: 28px 0; }
}
@media (max-width: 480px) { body { font-size: 17px; } }
@media (prefers-reduced-motion: reduce) { html { scroll-behavior: auto; } }
@media print { .skip-link, .contents, .back-to-top { display: none; } main { padding: 0; max-width: none; } }
</style></head><body><a class="skip-link" href="#main">Skip to content</a><main id="main"><header class="intro">${render(introduction)}</header>${contents}<div class="inventory">${html}</div><p class="back-to-top"><a href="#main">Back to top</a></p></main>${renderFooter('uses')}</body></html>
`);
await writeFile(`${destination}/index.md`, `${markdown.trimEnd()}\n\n---\n\nCanonical page: https://uses.mads-hartmann.com/\n`);
await copyFile(`${root}llms.txt`, `${destination}/llms.txt`);
