// The types and the decoders of the values that Elixir writes for the script.
//
// `Expresso.Test.SchemaWriter` writes this file from the forms of
// `Expresso.Presenter.Schema`. Do not change it by hand. After a change of a
// form, write the file again:
//
//     EXPRESSO_SCHEMA=write mix test test/expresso/presenter/schema_test.exs

import {
  boolean,
  integer,
  list,
  literal,
  nullable,
  number,
  object,
  oneOf,
  openObject,
  partial,
  string,
  tuple,
  union,
} from "./decode.ts";
import type { Decoder } from "./decode.ts";

// A view of the presenter.
export type View = "present" | "handout" | "speaker";
export const VIEWS: readonly View[] = ["present", "handout", "speaker"];
export const decodeView: Decoder<View> = /* @__PURE__ */ oneOf(VIEWS);

// A field of the state.
export type Field = "index" | "view" | "blank" | "digits" | "help" | "progress" | "every" | "overview" | "selected";
export const FIELDS: readonly Field[] = ["index", "view", "blank", "digits", "help", "progress", "every", "overview", "selected"];
export const decodeField: Decoder<Field> = /* @__PURE__ */ oneOf(FIELDS);

// A field of the state that holds true or false.
export type BooleanField = "blank" | "help" | "progress" | "every" | "overview";
export const BOOLEAN_FIELDS: readonly BooleanField[] = ["blank", "help", "progress", "every", "overview"];
export const decodeBooleanField: Decoder<BooleanField> = /* @__PURE__ */ oneOf(BOOLEAN_FIELDS);

// A field of the state that holds a number.
export type NumberField = "index" | "selected";
export const NUMBER_FIELDS: readonly NumberField[] = ["index", "selected"];
export const decodeNumberField: Decoder<NumberField> = /* @__PURE__ */ oneOf(NUMBER_FIELDS);

// The state of the presenter. The program holds its first value.
export type State = Readonly<{
  index: number;
  view: View;
  blank: boolean;
  digits: string;
  help: boolean;
  progress: boolean;
  every: boolean;
  overview: boolean;
  selected: number;
}>;
export const decodeState: Decoder<State> = /* @__PURE__ */ object({
  index: /* @__PURE__ */ integer(0),
  view: decodeView,
  blank: boolean,
  digits: /* @__PURE__ */ string(/^[0-9]*$/),
  help: boolean,
  progress: boolean,
  every: boolean,
  overview: boolean,
  selected: /* @__PURE__ */ integer(1),
});

// A built-in function of the browser.
export type Builtin = "open_speaker" | "fullscreen" | "reset_timer";
export const BUILTINS: readonly Builtin[] = ["open_speaker", "fullscreen", "reset_timer"];
export const decodeBuiltin: Decoder<Builtin> = /* @__PURE__ */ oneOf(BUILTINS);

// A part of the window under a click.
export type Region = "left_third" | "right";
export const REGIONS: readonly Region[] = ["left_third", "right"];
export const decodeRegion: Decoder<Region> = /* @__PURE__ */ oneOf(REGIONS);

// The direction of a swipe.
export type Direction = "left" | "right";
export const DIRECTIONS: readonly Direction[] = ["left", "right"];
export const decodeDirection: Decoder<Direction> = /* @__PURE__ */ oneOf(DIRECTIONS);

// A command of the program. `Expresso.Presenter.Definition` tells what each
// command does.
export type Command =
  | readonly ["set", "index", number]
  | readonly ["set", "view", View]
  | readonly ["set", "blank", boolean]
  | readonly ["set", "digits", string]
  | readonly ["set", "help", boolean]
  | readonly ["set", "progress", boolean]
  | readonly ["set", "every", boolean]
  | readonly ["set", "overview", boolean]
  | readonly ["set", "selected", number]
  | readonly ["toggle", BooleanField]
  | readonly ["clear", Field]
  | readonly ["assign", "selected", readonly ["entry", "slide"]]
  | readonly ["append", "digits"]
  | readonly ["step", number]
  | readonly ["goto", number | null]
  | readonly ["goto_slide", "selected" | number]
  | readonly ["select", number]
  | readonly ["select_by", number]
  | readonly ["go_typed"]
  | readonly ["builtin", Builtin];
export const decodeCommand: Decoder<Command> = /* @__PURE__ */ union(
  "command",
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("set"), /* @__PURE__ */ literal("index"), /* @__PURE__ */ integer(0)),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("set"), /* @__PURE__ */ literal("view"), decodeView),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("set"), /* @__PURE__ */ literal("blank"), boolean),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("set"), /* @__PURE__ */ literal("digits"), /* @__PURE__ */ string(/^[0-9]*$/)),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("set"), /* @__PURE__ */ literal("help"), boolean),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("set"), /* @__PURE__ */ literal("progress"), boolean),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("set"), /* @__PURE__ */ literal("every"), boolean),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("set"), /* @__PURE__ */ literal("overview"), boolean),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("set"), /* @__PURE__ */ literal("selected"), /* @__PURE__ */ integer(1)),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("toggle"), decodeBooleanField),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("clear"), decodeField),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("assign"), /* @__PURE__ */ literal("selected"), /* @__PURE__ */ tuple(/* @__PURE__ */ literal("entry"), /* @__PURE__ */ literal("slide"))),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("append"), /* @__PURE__ */ literal("digits")),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("step"), /* @__PURE__ */ integer()),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("goto"), /* @__PURE__ */ nullable(/* @__PURE__ */ integer(0))),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("goto_slide"), /* @__PURE__ */ union("\"selected\" | number", /* @__PURE__ */ literal("selected"), /* @__PURE__ */ integer(1))),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("select"), /* @__PURE__ */ integer(0)),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("select_by"), /* @__PURE__ */ integer()),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("go_typed")),
  /* @__PURE__ */ tuple(/* @__PURE__ */ literal("builtin"), decodeBuiltin),
);

// The commands of an event, or of an element under a click.
export type Commands = readonly Command[];
export const decodeCommands: Decoder<Commands> = /* @__PURE__ */ list(decodeCommand);

// A mode as the renderer writes it. Each pair holds each event that has the
// same commands.
export type WrittenMode = Readonly<{
  name: string;
  when: Readonly<{
    index?: number;
    view?: View;
    blank?: boolean;
    digits?: string;
    help?: boolean;
    progress?: boolean;
    every?: boolean;
    overview?: boolean;
    selected?: number;
  }>;
  any: Commands | null;
  other: Commands | null;
  element: Commands | null;
  keys: readonly (readonly [readonly string[], Commands])[];
  click: readonly (readonly [readonly Region[], Commands])[];
  swipe: readonly (readonly [readonly Direction[], Commands])[];
}>;
export const decodeWrittenMode: Decoder<WrittenMode> = /* @__PURE__ */ object({
  name: /* @__PURE__ */ string(),
  when: /* @__PURE__ */ partial({
    index: /* @__PURE__ */ integer(0),
    view: decodeView,
    blank: boolean,
    digits: /* @__PURE__ */ string(/^[0-9]*$/),
    help: boolean,
    progress: boolean,
    every: boolean,
    overview: boolean,
    selected: /* @__PURE__ */ integer(1),
  }),
  any: /* @__PURE__ */ nullable(decodeCommands),
  other: /* @__PURE__ */ nullable(decodeCommands),
  element: /* @__PURE__ */ nullable(decodeCommands),
  keys: /* @__PURE__ */ list(/* @__PURE__ */ tuple(/* @__PURE__ */ list(/* @__PURE__ */ string()), decodeCommands)),
  click: /* @__PURE__ */ list(/* @__PURE__ */ tuple(/* @__PURE__ */ list(decodeRegion), decodeCommands)),
  swipe: /* @__PURE__ */ list(/* @__PURE__ */ tuple(/* @__PURE__ */ list(decodeDirection), decodeCommands)),
});

// The projections as the renderer writes them. `Expresso.Presenter.Projection`
// tells what each one does.
export type WrittenProjections = Readonly<{
  attributes: readonly (readonly [BooleanField, string, true] | readonly [Field, string, false])[];
  properties: readonly (readonly [string, "fraction" | "done"])[];
  marks: readonly (readonly [string, string, "slide" | "index", readonly (readonly [string, NumberField, number])[]])[];
}>;
export const decodeWrittenProjections: Decoder<WrittenProjections> = /* @__PURE__ */ object({
  attributes: /* @__PURE__ */ list(/* @__PURE__ */ union("readonly [BooleanField, string, true] | readonly [Field, string, false]", /* @__PURE__ */ tuple(decodeBooleanField, /* @__PURE__ */ string(/^data-/), /* @__PURE__ */ literal(true)), /* @__PURE__ */ tuple(decodeField, /* @__PURE__ */ string(/^data-/), /* @__PURE__ */ literal(false)))),
  properties: /* @__PURE__ */ list(/* @__PURE__ */ tuple(/* @__PURE__ */ string(/^--/), /* @__PURE__ */ oneOf(["fraction", "done"]))),
  marks: /* @__PURE__ */ list(/* @__PURE__ */ tuple(/* @__PURE__ */ string(/^data-/), /* @__PURE__ */ string(), /* @__PURE__ */ oneOf(["slide", "index"]), /* @__PURE__ */ list(/* @__PURE__ */ tuple(/* @__PURE__ */ string(), decodeNumberField, /* @__PURE__ */ integer())))),
});

// The program of the presenter for one deck, as the renderer writes it.
export type WrittenProgram = Readonly<{
  state: State;
  modes: readonly WrittenMode[];
  project: WrittenProjections;
}>;
export const decodeWrittenProgram: Decoder<WrittenProgram> = /* @__PURE__ */ object({
  state: decodeState,
  modes: /* @__PURE__ */ list(decodeWrittenMode),
  project: decodeWrittenProjections,
});

// The kind of the transition into a slide.
export type Kind = "none" | "fade" | "slide" | "zoom";
export const KINDS: readonly Kind[] = ["none", "fade", "slide", "zoom"];
export const decodeKind: Decoder<Kind> = /* @__PURE__ */ oneOf(KINDS);

// One slide of the deck: the index of its step 1, its number of steps, and the
// transition into it.
export type Slide = Readonly<{
  first: number;
  steps: number;
  transition: Kind;
}>;
export const decodeSlide: Decoder<Slide> = /* @__PURE__ */ object({
  first: /* @__PURE__ */ integer(0),
  steps: /* @__PURE__ */ integer(1),
  transition: decodeKind,
});

// One step of the deck as the renderer writes it: the slide, the step, the
// fraction, the done part and the position.
export type WrittenEntry = readonly [number, number, number, number, string];
export const decodeWrittenEntry: Decoder<WrittenEntry> = /* @__PURE__ */ tuple(/* @__PURE__ */ integer(1), /* @__PURE__ */ integer(1), /* @__PURE__ */ number(0, 1), /* @__PURE__ */ number(0, 1), /* @__PURE__ */ string());

// The steps and the slides of a deck, as the renderer writes them.
export type WrittenDeck = Readonly<{
  steps: readonly WrittenEntry[];
  slides: readonly Slide[];
  duration_ms: number | null;
}>;
export const decodeWrittenDeck: Decoder<WrittenDeck> = /* @__PURE__ */ object({
  steps: /* @__PURE__ */ list(decodeWrittenEntry),
  slides: /* @__PURE__ */ list(decodeSlide),
  duration_ms: /* @__PURE__ */ nullable(/* @__PURE__ */ integer(1)),
});

// The source of each embed of a deck, in the order of the numbers of the
// elements, as the renderer writes it.
export type WrittenEmbeds = readonly (Readonly<{
  kind: "src" | "srcdoc";
  value: string;
}>)[];
export const decodeWrittenEmbeds: Decoder<WrittenEmbeds> = /* @__PURE__ */ list(/* @__PURE__ */ object({
  kind: /* @__PURE__ */ oneOf(["src", "srcdoc"]),
  value: /* @__PURE__ */ string(),
}));

// The message that one window of the presenter sends to the other window. The
// other window ignores a key that it does not know.
export type Message = Readonly<{
  expresso: "position";
  slide: number;
  step: number;
  blank: boolean;
  time: number;
}>;
export const decodeMessage: Decoder<Message> = /* @__PURE__ */ openObject({
  expresso: /* @__PURE__ */ literal("position"),
  slide: /* @__PURE__ */ integer(),
  step: /* @__PURE__ */ integer(),
  blank: boolean,
  time: /* @__PURE__ */ number(),
});
