import { Tag } from "@howto/tag";
import { Client } from "@notionhq/client";

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
  private databaseID: string;
  constructor(token: string, databaseID: string) {
    this.databaseID = databaseID;
    this.notion = new Client({
      auth: token,
    });
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
    const howtos = response.results.map((page) => {
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
    });

    return howtos;
  }
}
