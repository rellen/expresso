// The manifest of the recorder. `mix expresso.gifs` writes it, and
// `record.ts` reads it. This module does not touch the browser, so each
// function has a unit test.

// A key that the recorder presses, or a move of the clock of the page by a
// number of milliseconds. The speaker view then shows a later time.
export type Action = string | { advance: number };

// `address` is the query and the fragment after the path of the HTML file,
// such as `?speaker#2.1`. A still gives one PNG after the actions, and an
// example that is not a still gives a GIF of each action.
export type Example = {
  name: string;
  html: string;
  address: string;
  actions: Action[];
  still: boolean;
};

export function isAdvance(action: Action): action is { advance: number } {
  return typeof action !== "string";
}

// The name of the file of an example, in the output directory.
export function output(example: Example): string {
  return `${example.name}.${example.still ? "png" : "gif"}`;
}
