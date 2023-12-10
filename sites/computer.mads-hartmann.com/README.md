# computer.mads-hartmann.com

Building the site

```sh
cd sites/computer.mads-hartmann.com
nix-shell
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
node scripts/update-from-notion.js
```
