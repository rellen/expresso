// The sounds of the audio element. `media.ts` gives the rules, and
// `Expresso.Element.Audio` writes the elements and the files.
//
// A sound plays with its volume, so the browser plays it only after the
// first key or click of the presenter in the document. A sound of the first
// slide therefore starts at the first key.

import { player } from "./media.ts";

// Play each sound of the slide that shows at the step, and pause each other
// sound that played.
export const play = player("expresso-audios", "audio");
