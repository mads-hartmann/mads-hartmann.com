import Head from "next/head";
import { GetStaticProps } from "next";
import { HowTo, HowToDB } from "@howto/howto";
import css from "./index.module.scss";
import HowToList from "@components/HowToList";

export const getStaticProps: GetStaticProps = async (context) => {
  const db = new HowToDB(
    process.env.HOWTO_NOTION_TOKEN as string,
    process.env.HOWTO_NOTION_DATABASE_ID as string
  );
  const howtos = await db.list();
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
      <main className={css.main}>
        <HowToList howtos={props.howtos} />
      </main>
    </>
  );
}
