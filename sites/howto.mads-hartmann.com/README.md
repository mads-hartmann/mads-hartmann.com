# howto.mads-hartmann.com

**WIP**: This is still just a work in progress.

This is a small site for rendering my How-To entires.

The data is stored in a [Notion](https://www.notion.so/) database. It's a small [NextJS](https://nextjs.org/) application which is written in [TypeScript](https://www.typescriptlang.org/).

It uses the Notion API ([guide](https://developers.notion.com/docs), [reference](https://developers.notion.com/reference/intro)) to fetch the pages.

It uses [souvikinator/notion-to-md](https://github.com/souvikinator/notion-to-md) to fetch the Notion page contents as Markdown and then uses [remarkjs/react-markdown](https://github.com/remarkjs/react-markdown) to render it.

### TODOs

To finish the prototype

1. [x] Host it somewhere. Probably easiest just to use Vercel to be honest.
2. Make it possible to click each How-To to render a page for it
3. Possibly add a page for tags

Optional

- Play around with [Radix UI](https://www.radix-ui.com/) if I need nicer components

### Development

Ensure you have the appropriate environment variables set - they're stored in 1Password for now and have been added as Gitpod Variables so they're already present in workspaces I start. See [Credentials](#credentials) below for information about how the credentials were created.

```sh
npm install
npm run dev
```

### Credentials

Some notes on the credentials.

- `HOWTO_NOTION_TOKEN` was created by creating a Notion integration. It has read-only access to the content in my workspace. See [My Integration](https://www.notion.so/my-integrations). You need to add the integration to the database page in Notion by clicking the "..." and then "Add connections" before it gets access to your database.
- `HOWTO_NOTION__DATABASE_ID` the ID of the Notion database which contains the How-To documents. Can be found in the URL if you open the page for the database.
