// The copies of the large files of the document.
//
// `Expresso.Assets` keeps one copy of each large data URI that the document
// holds more than one time. The first element with the value has
// `data-asset-N`, with the name of the attribute that holds it, such as
// `data-asset-0="src"`. Each other element has `data-asset-src="0"` or
// `data-asset-poster="0"` in place of the value. `restore` copies the value
// into each of these elements when the document loads.

// The attributes that `Expresso.Assets` can replace.
const NAMES = ["src", "poster"] as const;

// A part of the DOM that `restore` reads and writes. The document is one, and
// a test gives a fake.
export type Root = Pick<ParentNode, "querySelector" | "querySelectorAll">;

// Copy each value back into the elements that refer to it. A reference with
// no first element stays as it is.
export function restore(root: Root): void {
  for (const name of NAMES) {
    for (const element of root.querySelectorAll(`[data-asset-${name}]`)) {
      const id = element.getAttribute(`data-asset-${name}`);
      const first = root.querySelector(`[data-asset-${id}]`);
      const holder = first?.getAttribute(`data-asset-${id}`);
      const value = holder ? first?.getAttribute(holder) : null;
      if (value) {
        element.setAttribute(name, value);
      }
    }
  }
}
