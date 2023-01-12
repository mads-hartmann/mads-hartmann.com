import { useMemo, useReducer } from "react";
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

function filter(howtos: HowTo[], query: string): HowTo[] {
  if (!query) {
    return howtos
  }
  const reqex = new RegExp(`.*${query}.*`, "ig");
  return howtos.filter((howto) => reqex.test(howto.name))
}

type State = {
  query: string;
  filtered: HowTo[];
  all: HowTo[]
};

function reducer(state: State, action: any) {
  switch (action.type) {
    case "query":
      if (state.query != action.query) {
        return { ...state, query: action.query, filtered: filter(state.all, action.query) };
      } else {
        return state
      }
    default:
      throw new Error(`unknown action: ${action}`);
  }
}

export default function Home(props: HomeProps) {
  // TODO: Something is off here. It invokes the reducer twice.
  const [state, dispath] = useReducer(reducer, { query: "", filtered: props.howtos, all: props.howtos });
  return (
    <>
      <Head>
        <title>howto.mads-hartmann.com</title>
        <meta name="description" content="Mads' How-To notes" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>
      <main className={css.main}>
        <div className={css.info}>
          <div>
            <h1>How to...</h1>
            <p>This is my collection of {props.howtos.length} short how-to notes for how to accomplish common tasks. I only recently started collecting these so I don&apos;t have that many yet.</p>
          </div>
          <input
            className={css.input}
            type="text"
            placeholder="Search"
            onChange={(event) => {
              dispath({ type: "query", query: event.target.value })
            }}
          />
        </div>
        <div className={css.list}>
          <HowToList howtos={state.filtered} />
        </div>
      </main>
    </>
  );
}
