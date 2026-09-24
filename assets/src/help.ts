// The rows of the list of keys. This module does not touch the document, so
// each function has a unit test.

import { BINDINGS } from "./state.ts";
import type { Binding, View } from "./state.ts";

// The names that the list of keys shows for the values of `KeyboardEvent.key`.
// A key that is not in this table shows its value.
const NAMES: Record<string, string> = {
  " ": "Space",
  ArrowRight: "→",
  ArrowLeft: "←",
  ArrowUp: "↑",
  ArrowDown: "↓",
  PageDown: "Page Down",
  PageUp: "Page Up",
};

// The names of the keys of a binding, such as `j, →, ↓, Page Down, Space`.
export function names(binding: Binding): string {
  if (binding.label !== undefined) {
    return binding.label;
  }
  return binding.keys.map((key) => NAMES[key] ?? key).join(", ");
}

// The rows of the list of keys of a view, in the order of the table.
export function rows(view: View): [string, string][] {
  return BINDINGS.filter((binding) => binding.views.includes(view)).map(
    (binding) => [names(binding), binding.text],
  );
}
