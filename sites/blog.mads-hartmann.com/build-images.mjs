import { mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';

// The widest article is 768 CSS pixels; retain enough detail for 2x displays.
const widths = [320, 640, 768, 960, 1280, 1536];
const [source, destination, references] = process.argv.slice(2);
if (!source || !destination || !references) throw new Error('Usage: node build-images.mjs SOURCE DESTINATION REFERENCES_JSON');
await rm(destination, { recursive: true, force: true });
const manifest = {};
for (const url of [...new Set(JSON.parse(references))].sort()) {
  if (!/^\/images\/[\w/.-]+\.(png|jpe?g)$/i.test(url) || url.includes('..')) {
    throw new Error(`Unsupported image source: ${url}`);
  }
  const entry = url.slice('/images/'.length);
  const input = path.join(source, url);
  const { width, height } = await sharp(input).metadata();
  const sizes = [...new Set([...widths.filter(size => size < width), Math.min(width, 1536)])];
  const variants = [];
  for (const size of sizes) {
    const url = `/images/responsive/${entry.replace(/\.[^.]+$/, '')}-${size}.webp`;
    const output = path.join(destination, url);
    await mkdir(path.dirname(output), { recursive: true });
    // High quality preserves screenshot text while substantially reducing payloads.
    await sharp(input).resize({ width: size, withoutEnlargement: true }).webp({ quality: 90, smartSubsample: true, effort: 6 }).toFile(output);
    variants.push({ url, width: size });
  }
  manifest[`/images/${entry}`] = {
    width, height,
    src: variants.find(variant => variant.width >= 640)?.url ?? variants.at(-1).url,
    srcset: variants.map(variant => `${variant.url} ${variant.width}w`).join(', '),
    variants
  };
}
process.stdout.write(JSON.stringify(manifest));
