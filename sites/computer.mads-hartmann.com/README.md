# computer.mads-hartmann.com

Building the site

```sh
cd sites/computer.mads-hartmann.com
nix-shell
npm i
node scripts/build.js
```

Previewing it

```sh
nix-shell
node scripts/serve.js
```

Updating from Notion

```sh
nix-shell
export NOTION_TOKEN=""
node scripts/update-from-notion.js
```
