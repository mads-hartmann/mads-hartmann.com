import { useReducer } from "react";
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

type State = {
  query: string;
  howtos: HowTo[];
};

function reducer(state: State, action: any) {
  switch (action.type) {
    case "query":
      return { ...state, query: action.query };
    default:
      throw new Error(`unknown action: ${action}`);
  }
}

export default function Home(props: HomeProps) {
  const [state, dispath] = useReducer(reducer, {
    query: "",
    howtos: props.howtos,
  });
  return (
    <>
      <Head>
        <title>howto.mads-hartmann.com</title>
        <meta name="description" content="Mads' How-To notes" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>
      <main className={css.main}>
        <div className={css.info}>
          <h1>How do I...</h1>
          <p>Type below to filter</p>
          <input
            type="text"
            onChange={(event) =>
              dispath({ type: "query", query: event.target.value })
            }
          />
          <p>Search my tiny collections of {props.howtos.length} how-tos</p>
          <button>New</button>
        </div>
        <div className={css.list}>
          <HowToList howtos={props.howtos} />
        </div>
      </main>
    </>
  );
}
