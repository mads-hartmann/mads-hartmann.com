import HowToItem from "@components/HowToItem";
import { HowTo } from "@howto/howto";
import css from "./HowToList.module.scss";

type HowToListProps = {
  howtos: HowTo[];
};

export default function HowToList(props: HowToListProps) {
  return (
    <ul className={css.list}>
      {props.howtos.map((howto) => {
        return <HowToItem key={howto.notion.id} howto={howto} />;
      })}
    </ul>
  );
}
