// The variant of a theme with a light and a dark variant. The renderer writes
// `data-variants` on the `html` element of such a document. The variant starts
// from the scheme of the screen, and the key `t` chooses the other variant.
// `data-scheme` on the `html` element then holds the choice, and it wins over
// the scheme of the screen.
//
// The two windows of the presenter show the same variant. The choice goes in
// each message between them, and `?scheme=` in the address gives it to a new
// window, such as the speaker view.
//
// `schema.ts` declares `Scheme`: `"light"`, `"dark"`, or `null` for the
// variant of the screen.

import type { Scheme } from "./schema.ts";

export type { Scheme } from "./schema.ts";

// The variant that the key `t` shows: the other variant of the variant that
// the window shows now.
export function next(chosen: Scheme, darkScreen: boolean): "light" | "dark" {
  const dark = chosen === null ? darkScreen : chosen === "dark";
  return dark ? "light" : "dark";
}

// The variant of the address parameter `?scheme=`, or null for a value that is
// not a variant.
export function fromAddress(value: string | null): Scheme {
  return value === "light" || value === "dark" ? value : null;
}
