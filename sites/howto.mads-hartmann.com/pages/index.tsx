import Head from "next/head";
import { GetStaticProps } from "next";
import { Client } from "@notionhq/client";

const notion = new Client({
  auth: process.env.NOTION_TOKEN,
});

export const getStaticProps: GetStaticProps = async (context) => {
  const response = await notion.databases.query({
    database_id: process.env.NOTION_HOW_TO_DATABASE_ID as string,
    sorts: [
      {
        property: 'Created time',
        direction: 'descending',
      },
    ],
  });
  const howtos = response.results.map((page) => {
    const name = page.properties['Name'].title[0]['plain_text']
    const tags = page.properties['Tags']['multi_select'].map((tag) => ({
      id: tag.id,
      name: tag.name,
      color: tag.color,
    }))
    return {
      name,
      tags,
      notion: {
        id: page.id,
        url: page.url
      }
    }
  })
  return { props: { howtos } };
};

type Tag = {
  id: string
  name: string
  color: string
}

type HowTo = {
  name: string
  tags: Tag[]
  notion: {
    url: string
    id: string
  }
}

type HomeProps = {
  howtos: HowTo[]
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
            return (
              <li>{howto.name}</li>
            )
          })}
        </ul>
      </main>
    </>
  );
}
