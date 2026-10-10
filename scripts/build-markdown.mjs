import { copyFile, readFile, readdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseHTML } from 'linkedom';
import TurndownService from 'turndown';
import { gfm } from 'turndown-plugin-gfm';

const sites = {
  homepage: {
    origin: 'https://www.mads-hartmann.com',
    sourceDir: 'sites/mads-hartmann.com',
  },
  uses: {
    origin: 'https://uses.mads-hartmann.com',
    sourceDir: 'sites/uses.mads-hartmann.com',
  },
  blog: {
    origin: 'https://blog.mads-hartmann.com',
    sourceDir: 'sites/blog.mads-hartmann.com',
  },
};

const turndown = new TurndownService({ headingStyle: 'atx', codeBlockStyle: 'fenced', bulletListMarker: '-' });
turndown.use(gfm);
// Rouge puts the language on a wrapper and spans inside <code>. Preserve the
// actual code text and choose a fence that cannot be closed by its contents.
turndown.addRule('codeBlocks', {
  filter: 'pre',
  replacement(_content, node) {
    const code = node.querySelector('code') || node;
    let language = '';
    for (let parent = code; parent && !language; parent = parent.parentNode) {
      language = /(?:language-|lang-)([\w+-]+)/.exec(parent.getAttribute?.('class') || '')?.[1] || '';
    }
    const text = code.textContent.replace(/\n$/, '');
    const longest = Math.max(2, ...(text.match(/`+/g) || []).map(fence => fence.length));
    const fence = '`'.repeat(longest + 1);
    return `\n\n${fence}${language}\n${text}\n${fence}\n\n`;
  },
});
// Semantic inline elements used as separate lines in the homepage timeline.
turndown.addRule('timelineLines', {
  filter: node => /experience__(?:title|duration|location)/.test(node.getAttribute?.('class') || ''),
  replacement: content => `\n\n${content}\n\n`,
});

export function pageMarkdown(html, canonicalURL, markdownURLs) {
  const { document } = parseHTML(html);
  const content = document.querySelector('main, .site');
  if (!content) throw new Error(`No main content in ${canonicalURL}`);
  const title = (content.querySelector('h1')?.textContent || document.title).trim();
  content.querySelectorAll('script, style, nav, footer, template, #disqus_thread').forEach(node => node.remove());
  // Older blog layouts put the excerpt first. Lead with the title and date,
  // retaining the excerpt exactly once.
  const articleTitle = content.querySelector(':scope > .title');
  if (articleTitle) content.prepend(articleTitle);
  for (const node of content.querySelectorAll('[href], [src]')) {
    for (const attribute of ['href', 'src']) {
      const value = node.getAttribute(attribute);
      if (!value) continue;
      if (value.startsWith('data:')) {
        // Embedded portraits and logos can dwarf the text. Preserve useful alt
        // text, without putting base64 image data in the agent's context.
        if (node.tagName === 'IMG') node.replaceWith(document.createTextNode(node.getAttribute('alt') || ''));
        continue;
      }
      const url = new URL(value, canonicalURL);
      // Fragments target IDs from HTML (including footnotes and custom anchors).
      // Keep those on the canonical page instead of promising Markdown anchors.
      if (attribute === 'href' && !url.hash && markdownURLs.has(url.href)) url.href = markdownURLs.get(url.href);
      node.setAttribute(attribute, url.href);
    }
  }
  for (const node of content.querySelectorAll('iframe, audio, video')) {
    const sources = [node, ...node.querySelectorAll('source')].map(source => source.getAttribute('src')).filter(Boolean);
    const links = document.createElement('p');
    for (const source of sources) {
      const link = document.createElement('a');
      link.href = source;
      link.textContent = node.getAttribute('title') || `${node.tagName.toLowerCase()} recording`;
      links.append(link, document.createElement('br'));
    }
    node.replaceWith(links);
  }
  let markdown = turndown.turndown(content.innerHTML);
  if (!content.querySelector('h1')) markdown = `# ${title}\n\n${markdown}`;
  return `${markdown}\n\n---\n\nCanonical page: ${canonicalURL}\n`;
}

export async function buildMarkdown(site, directory) {
  const config = sites[site];
  if (!config) throw new Error(`Unknown site: ${site}`);
  const pages = [];
  for (const file of (await readdir(directory, { recursive: true })).sort()) {
    if (!file.endsWith('.html')) continue;
    const html = await readFile(`${directory}/${file}`, 'utf8');
    if (!/<html[\s>]/i.test(html)) continue;
    const canonical = new URL(file.replace(/index\.html$/, ''), `${config.origin}/`).href;
    pages.push({ file, html, canonical, markdown: `${config.origin}/${file.replace(/\.html$/, '.md')}` });
  }
  const markdownURLs = new Map();
  for (const page of pages) {
    markdownURLs.set(page.canonical, page.markdown);
    markdownURLs.set(`${config.origin}/${page.file}`, page.markdown);
    if (page.canonical.endsWith('/') && page.file !== 'index.html') markdownURLs.set(page.canonical.slice(0, -1), page.markdown);
  }
  for (const page of pages) {
    await writeFile(`${directory}/${page.file.replace(/\.html$/, '.md')}`, pageMarkdown(page.html, page.canonical, markdownURLs));
    // Insert metadata only; do not reserialize or alter the visible HTML.
    const discovery = `<link rel="alternate" type="text/markdown" href="${page.markdown}">\n<link rel="describedby" type="text/plain" href="${config.origin}/llms.txt">\n`;
    await writeFile(`${directory}/${page.file}`, page.html.replace('</head>', `${discovery}</head>`));
  }
  await copyFile(`${config.sourceDir}/llms.txt`, `${directory}/llms.txt`);
  console.log(`${site}: generated ${pages.length} Markdown pages and copied llms.txt`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [site, directory = `.build/${site}`] = process.argv.slice(2);
  await buildMarkdown(site, directory);
}
