import { copyFile, readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';
import { renderFooter } from '../shared/footer/render.mjs';

const root = fileURLToPath(new URL('.', import.meta.url));
const destination = process.argv[2] || `${root}dist`;
const markdown = await readFile(`${root}index.md`, 'utf8');
const html = marked.parse(markdown, { async: false });
const headings = [...html.matchAll(/<h2 id="([^"]+)">([^<]+)<\/h2>/g)];
const intro = html.slice(0, headings[0].index);
const sections = headings.map(([heading, id, title], i) => {
  const body = html.slice(headings[i].index + heading.length, headings[i + 1]?.index ?? html.length);
  return `<section id="${id}" aria-labelledby="${id}-title"><h2 id="${id}-title">${title}</h2><div class="section-content">${body}</div></section>`;
}).join('\n');
const content = `<header class="intro">${intro}</header><div>${sections}</div>`;
await mkdir(destination, { recursive: true });
await writeFile(`${destination}/index.html`, `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Computer — Mads Hartmann</title><meta name="description" content="How I set up my Mac: installing tools, configuring my shell and using SSH with 1Password.">
<link rel="canonical" href="https://computer.mads-hartmann.com/">
<link rel="alternate" type="text/markdown" href="https://computer.mads-hartmann.com/index.md">
<link rel="describedby" type="text/plain" href="https://computer.mads-hartmann.com/llms.txt">
<meta name="color-scheme" content="light dark">
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
.intro p + p { font-size: 14px; color: var(--mh-color-muted); }
p { margin: 0 0 20px; }
section { display: grid; grid-template-columns: 175px minmax(0, 1fr); gap: 25px; padding: 32px 0; scroll-margin-top: 24px; }
section:first-child { padding-top: 0; }
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
@media (max-width: 700px) {
  main { padding-top: 36px; }
  section { grid-template-columns: minmax(0, 1fr); gap: 20px; padding: 28px 0; }
}
@media (max-width: 480px) { body { font-size: 17px; } }
@media (prefers-reduced-motion: reduce) { html { scroll-behavior: auto; } }
@media print { .skip-link { display: none; } main { padding: 0; max-width: none; } }

pre { max-width: 100%; overflow-x: auto; padding: 16px; background: color-mix(in srgb, var(--mh-color-accent) 8%, var(--mh-color-surface)); border-radius: 6px; font-size: .85rem; line-height: 1.6; overflow-wrap: normal; }
code { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: .9em; }
pre code { font-size: inherit; }
table { display: block; max-width: 100%; overflow-x: auto; border-collapse: collapse; font-size: .9rem; }
th, td { padding: 8px 12px; border: 1px solid var(--mh-color-border); text-align: left; }
details { margin: 16px 0; }
summary { cursor: pointer; font-weight: 600; }
summary:focus-visible { outline: 2px solid var(--mh-color-accent); outline-offset: 4px; }
hr { border: 0; border-top: 1px solid var(--mh-color-border); margin: 32px 0; }
</style></head><body><a class="skip-link" href="#main">Skip to content</a><main id="main">${content}</main>${renderFooter('computer')}</body></html>
`);
await writeFile(`${destination}/index.md`, `${markdown.trimEnd()}\n\n---\n\nCanonical page: https://computer.mads-hartmann.com/\n`);
for (const file of ['llms.txt', 'robots.txt', 'sitemap.xml']) {
  await copyFile(`${root}${file}`, `${destination}/${file}`);
}
