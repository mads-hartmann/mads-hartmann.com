import Head from "next/head";
import { GetStaticProps } from "next";
import { Client } from "@notionhq/client";
import HowToItem from "@components/HowToItem";
import { HowTo } from "@howto/howto"

const notion = new Client({
  auth: process.env.NOTION_TOKEN,
});

export const getStaticProps: GetStaticProps = async (context) => {
  const response = await notion.databases.query({
    database_id: process.env.NOTION_HOW_TO_DATABASE_ID as string,
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
  return { props: { howtos } };
};


type HomeProps = {
  howtos: HowTo[];
};

export default function Home(props: HomeProps) {
  return (
    <>
      <Head>
        <title>howto.mads-hartmann.com</title>
        <meta name="description" content="Mads' How-To notes" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>
      <main>
        <ul>
          {props.howtos.map((howto) => {
            return <HowToItem key={howto.notion.id} howto={howto} />;
          })}
        </ul>
      </main>
    </>
  );
}
