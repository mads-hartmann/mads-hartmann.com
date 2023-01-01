import {HowTo} from "@howto/howto"

type Props = {
    howto: HowTo
}

export default function HowToItem({howto}: Props) {
    return (
        <p>{howto.name}</p>
    )
}
