// The search of the list of keys.
//
// The renderer writes the words of each row of the list into `data-words`,
// in lower case: the names of its keys, its label and its text. `search` hides
// each row whose words do not hold the typed text, and it opens each section
// with a row that matches. The style sheet then hides each empty list, heading
// and section, and it shows a line when no row matches. An empty text shows
// each row again.

// Show the rows of the list of keys that match a text.
export function search(dialog: HTMLElement, typed: string): void {
  const text = typed.trim().toLowerCase();
  const field = dialog.querySelector<HTMLInputElement>("#help-filter");
  if (field !== null && field.value !== typed) {
    field.value = typed;
  }
  dialog.toggleAttribute("data-searching", text !== "");
  for (const row of dialog.querySelectorAll<HTMLElement>("li[data-words]")) {
    row.hidden = text !== "" && !(row.dataset.words ?? "").includes(text);
  }
  if (text === "") {
    return;
  }
  for (const section of dialog.querySelectorAll<HTMLDetailsElement>(
    "details[data-mode]",
  )) {
    section.open =
      section.hasAttribute("data-current") ||
      section.querySelector("li:not([hidden])") !== null;
  }
}
