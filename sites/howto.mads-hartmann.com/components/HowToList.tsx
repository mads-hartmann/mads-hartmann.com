import HowToItem from "@components/HowToItem";
import { HowTo } from "@howto/howto";

type HowToListProps = {
  howtos: HowTo[];
};

export default function HowToList(props: HowToListProps) {
  return (
    <ul>
      {props.howtos.map((howto) => {
        return <HowToItem key={howto.notion.id} howto={howto} />;
      })}
    </ul>
  );
}
