import Link from "next/link";
import { HowTo } from "@howto/howto";

type Props = {
  howto: HowTo;
};

export default function HowToItem({ howto }: Props) {
  return (
    <div>
      <p></p>
      <Link
        href={{
          pathname: "/howto/[id]",
          query: { id: howto.notion.id },
        }}
      >
        {howto.name}
      </Link>
    </div>
  );
}
