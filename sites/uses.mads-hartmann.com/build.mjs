import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';
const root = fileURLToPath(new URL('.', import.meta.url));
const destination = process.argv[2] || `${root}dist`;
const markdown = await readFile(`${root}index.md`, 'utf8');
const html = marked.parse(markdown, { async: false });
await mkdir(destination, { recursive: true });
await writeFile(`${destination}/index.html`, `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Uses — Mads Hartmann</title><meta name="description" content="The hardware, software and equipment I use.">
<link rel="canonical" href="https://uses.mads-hartmann.com/">
<style>*{box-sizing:border-box}html{color-scheme:light}body{margin:0;background:#faf9f6;color:#292923;font:18px/1.65 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}main{max-width:680px;margin:0 auto;padding:64px 24px 48px}a{color:#375a42;text-underline-offset:4px}a:hover{color:#192b20}a:focus-visible{outline:2px solid #375a42;outline-offset:4px}header{margin-bottom:32px}nav{display:flex;gap:24px;flex-wrap:wrap}h1{font-size:2rem;line-height:1.2;letter-spacing:-.04em;margin:20px 0 8px}h2{font-size:1.1rem;margin:32px 0 8px}p{margin:0 0 20px}ul{padding-left:24px}li{margin:8px 0}.portrait{width:104px;height:104px;border-radius:50%;object-fit:cover}.socials{list-style:none;padding:0;display:flex;gap:24px;flex-wrap:wrap}footer{margin-top:48px;font-size:.85rem;color:#626258}@media(max-width:480px){main{padding-top:32px}body{font-size:17px}}</style></head><body><main><nav aria-label="My sites"><a href="https://www.mads-hartmann.com/">Mads Hartmann</a><a href="https://blog.mads-hartmann.com/">Blog</a></nav>${html}</main></body></html>
`);
