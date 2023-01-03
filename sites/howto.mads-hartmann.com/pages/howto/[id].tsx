import { GetStaticProps, GetStaticPaths } from "next";
import { HowTo, HowToDB } from "@howto/howto";
import ReactMarkdown from "react-markdown";

export const getStaticProps: GetStaticProps = async (context) => {
  const { id } = context.params;
  const db = new HowToDB(
    process.env.HOWTO_NOTION_TOKEN as string,
    process.env.HOWTO_NOTION_DATABASE_ID as string
  );
  const howto = await db.get(id as string);
  const markdown = await db.getMarkdown(id as string);
  return {
    props: { howto, markdown },
  };
};

export const getStaticPaths: GetStaticPaths = async () => {
  const db = new HowToDB(
    process.env.HOWTO_NOTION_TOKEN as string,
    process.env.HOWTO_NOTION_DATABASE_ID as string
  );

  const howtos = await db.list();

  const paths = howtos.map((howto) => ({
    params: { id: howto.notion.id },
  }));

  return { paths, fallback: false };
};

type HowToPageProps = {
  howto: HowTo;
  markdown: string;
};

export default function HowToPage(props: HowToPageProps) {
  return (
    <>
      <h1>{props.howto.name}</h1>
      <ReactMarkdown>{props.markdown}</ReactMarkdown>
    </>
  );
}
