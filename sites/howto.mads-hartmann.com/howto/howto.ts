import { Tag } from "@howto/tag"

export type HowTo = {
  name: string;
  tags: Tag[];
  notion: {
    url: string;
    id: string;
  };
};
