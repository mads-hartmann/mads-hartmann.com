import { Tag } from "@howto/tag";
import { Client } from "@notionhq/client";
import { NotionToMarkdown } from "notion-to-md";

/**
 * Contains meta-data about a HowTo page. It doesn't contain the page contents.
 */
export type HowTo = {
  name: string;
  tags: Tag[];
  notion: {
    url: string;
    id: string;
  };
};

export class HowToDB {
  private notion: Client;
  private n2m: NotionToMarkdown;
  private databaseID: string;
  constructor(token: string, databaseID: string) {
    this.databaseID = databaseID;
    this.notion = new Client({
      auth: token,
    });
    this.n2m = new NotionToMarkdown({ notionClient: this.notion });
  }

  async get(pageID: string): Promise<HowTo> {
    const response = await this.notion.pages.retrieve({
      page_id: pageID,
    });
    return this.parse(response);
  }

  async getMarkdown(pageID: string): Promise<string> {
    const mdblocks = await this.n2m.pageToMarkdown(pageID);
    return this.n2m.toMarkdownString(mdblocks);
  }

  async list(): Promise<HowTo[]> {
    const response = await this.notion.databases.query({
      database_id: this.databaseID,
      sorts: [
        {
          property: "Created time",
          direction: "descending",
        },
      ],
    });
    return response.results.map((page) => this.parse(page));
  }

  private parse(page: any): HowTo {
    const name = page.properties["Name"].title[0]["plain_text"];
    const tags = page.properties["Tags"]["multi_select"].map((tag) => ({
      id: tag.id,
      name: tag.name,
      color: tag.color,
    }));
    return {
      name,
      tags,
      notion: {
        id: page.id,
        url: page.url,
      },
    };
  }
}
