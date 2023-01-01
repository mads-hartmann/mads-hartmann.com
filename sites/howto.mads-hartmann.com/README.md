# howto.mads-hartmann.com

**WIP**: This is still just a work in progress.

This is a small site for rendering my How-To entires.

The data is stored in a [Notion] database. It's a small [NextJS] application which is written in [TypeScript].

### TODOs

To finish the prototype

1. Host it somewhere. Probably easiest just to use Vercel to be honest.
2. Make it possible to click each How-To to render a page for it
3. Possibly add a page for tags

### Development

Put the relevant credentials in `.env` - they're stored in 1Password for now. See [Credentials](#credentials) below for information about how the credentials were created.

```sh
touch .env
# Copy in the credentials from 1password.
```

Start the development server

```sh
npm run dev
```

### Credentials

Some notes on the credentials.

- `NOTION_TOKEN` was created by creating a Notion integration. It has read-only access to the content in my workspace. See [My Integration](https://www.notion.so/my-integrations). You need to add the integration to the database page in Notion by clicking the "..." and then "Add connections" before it gets access to your database.

### References

- [Notion API getting started guide](https://developers.notion.com/docs)
- [Notion API reference](https://developers.notion.com/reference/intro)
