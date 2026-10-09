// The videos of the video element. `media.ts` gives the rules, and
// `Expresso.Element.Video` writes the elements and the files.

import { player } from "./media.ts";
export { shows } from "./media.ts";
export type { Media as Video } from "./media.ts";

// Play each video of the slide that shows at the step, and pause each other
// video that played.
export const play = player("expresso-videos", "video");
