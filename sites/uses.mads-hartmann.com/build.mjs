import { copyFile, readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';
import { renderFooter } from '../shared/footer/render.mjs';
const root = fileURLToPath(new URL('.', import.meta.url));
const destination = process.argv[2] || `${root}dist`;
const markdown = await readFile(`${root}index.md`, 'utf8');
const html = marked.parse(markdown, { async: false });
await mkdir(destination, { recursive: true });
await writeFile(`${destination}/index.html`, `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Uses — Mads Hartmann</title><meta name="description" content="The hardware, software and equipment I use.">
<link rel="canonical" href="https://uses.mads-hartmann.com/">
<link rel="alternate" type="text/markdown" href="https://uses.mads-hartmann.com/index.md">
<link rel="describedby" type="text/plain" href="https://uses.mads-hartmann.com/llms.txt">
<style>:root{--mh-color-surface:#faf9f6;--mh-color-text:#292923;--mh-color-border:#e3e2db;--mh-color-accent:#375a42;--mh-color-accent-subtle:#e7ece5;--mh-color-on-accent-subtle:#375a42}*{box-sizing:border-box}html{color-scheme:light}body{margin:0;background:var(--mh-color-surface);color:var(--mh-color-text);font:18px/1.65 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}main{max-width:680px;margin:0 auto;padding:40px 24px 0}a{color:var(--mh-color-accent);text-underline-offset:4px}a:hover{color:#192b20}a:focus-visible{outline:2px solid var(--mh-color-accent);outline-offset:4px}h1{font-size:2rem;line-height:1.2;letter-spacing:-.04em;margin:0 0 24px}h2{font-size:1.1rem;margin:32px 0 8px}h3{font-size:1rem;margin:24px 0 8px}p{margin:0 0 20px}ul{padding-left:24px}li{margin:8px 0}@media(max-width:480px){main{padding-top:32px}body{font-size:17px}}</style></head><body><main>${html}</main>${renderFooter('uses')}</body></html>
`);
await writeFile(`${destination}/index.md`, `${markdown.trimEnd()}\n\n---\n\nCanonical page: https://uses.mads-hartmann.com/\n`);
await copyFile(`${root}llms.txt`, `${destination}/llms.txt`);
