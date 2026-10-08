import { test } from "node:test";
import assert from "node:assert/strict";
import { commands, parse } from "../src/program.ts";
import { raw, texts } from "./fixtures.ts";
import { DecodeError } from "../src/decode.ts";
import { validate, validateCommands } from "./validate.ts";

const text = texts("1,2").program;

// A copy of the program with one change.
function changed(change: (data: Record<string, any>) => void): string {
  const data = JSON.parse(text);
  change(data);
  return JSON.stringify(data);
}

function present(data: Record<string, any>) {
  return data.modes.find((mode: { name: string }) => mode.name === "present");
}

test("parse reads the program that the renderer writes", () => {
  const program = parse(text);

  assert.equal(program.state.view, "present");
  assert.deepEqual(
    program.modes.map((mode) => mode.name),
    ["blank", "help", "overview", "menu", "present", "speaker", "handout"],
  );
  const mode = program.modes[4];
  assert.deepEqual(mode?.keys.get("j"), [
    ["clear", "digits"],
    ["step", 1],
  ]);
  assert.deepEqual(mode?.keys.get(" "), mode?.keys.get("j"));
  assert.deepEqual(mode?.click.get("left_third"), [
    ["clear", "digits"],
    ["step", -1],
  ]);
  assert.deepEqual(mode?.element, [["clear", "digits"]]);
  assert.deepEqual(program.modes[2]?.element, []);
  assert.deepEqual(program.modes[3]?.keys.get("Enter"), [
    ["go", "cursor"],
    ["set", "menu", false],
  ]);
  assert.equal(program.modes[5]?.element, null);
});

test("validate refuses a program that the renderer does not write", () => {
  const texts = [
    "null",
    "[]",
    changed((data) => delete data.state.digits),
    changed((data) => (data.state.extra = 1)),
    changed((data) => (data.state.view = "stage")),
    changed((data) => (data.state.blank = "no")),
    changed((data) => (data.modes = {})),
    changed((data) => (data.modes[0].when = { color: "red" })),
    changed((data) => (data.modes[0].when = { view: 3 })),
    changed((data) => (data.modes[0].any = [["jump", 1]])),
    changed((data) => (data.modes[0].any = [["set", "blank", 1]])),
    changed((data) => (data.modes[0].any = [["toggle", "digits"]])),
    changed((data) => (data.modes[0].any = [["step", 1.5]])),
    changed((data) => (data.modes[0].any = [["builtin", "print"]])),
    changed((data) => (data.modes[0].any = [["set", "view", "stage"]])),
    changed((data) => (present(data).keys = [[["j"], "step"]])),
    changed((data) => (present(data).keys = [[[1], []]])),
    changed((data) => (present(data).element = "no")),
    changed((data) => (present(data).element = [["goto", "x"]])),
    changed((data) => delete data.project),
    changed(
      (data) => (data.project.attributes = [["color", "data-color", false]]),
    ),
    changed(
      (data) => (data.project.attributes = [["view", "data-view", "no"]]),
    ),
    changed((data) => (data.project.properties = [["--x", "position"]])),
    changed((data) => (data.project.marks = [["data-a", ".a", "step", []]])),
    changed(
      (data) =>
        (data.project.marks = [["data-a", ".a", "slide", [["", "view", 0]]]]),
    ),
  ];
  for (const each of texts) {
    assert.throws(() => validate(each), DecodeError, each.slice(0, 80));
  }
});

test("parse reads the projections that the renderer writes", () => {
  const { project } = parse(text);

  assert.deepEqual(project.attributes[0], {
    field: "view",
    name: "data-view",
    flag: false,
  });
  assert.deepEqual(project.properties, [
    { name: "--fraction", entry: "fraction" },
  ]);
  assert.deepEqual(
    project.marks.map((mark) => [mark.attribute, mark.values, mark.scroll]),
    [
      ["data-selected", [["", "selected", 0]], false],
      [
        "data-speaker",
        [
          ["current", "index", 0],
          ["next", "index", 1],
        ],
        false,
      ],
      ["data-cursor", [["", "cursor", 0]], true],
      ["data-current", [["", "index", 0]], false],
    ],
  );
});

test("commands reads the commands of a page of the overview", () => {
  assert.deepEqual(commands('[["goto_slide",2],["set","overview",false]]'), [
    ["goto_slide", 2],
    ["set", "overview", false],
  ]);
});

test("validateCommands refuses commands that the renderer does not write", () => {
  assert.throws(() => validateCommands('[["goto_slide","x"]]'), {
    message: "$[0]: expected command",
  });
});

// The script trusts the program, so these tests examine each program of the
// fixture file. The fixture file holds the program of each deck of the tests.
test("each program of the fixture file is valid, and parse reads it as validate does", () => {
  for (const [name, { program }] of Object.entries(raw.decks)) {
    const source = JSON.stringify(program);
    assert.deepEqual(parse(source), validate(source), name);
  }
});

// The fixture file also holds clicks on a page of a slide below 1, so the tests
// make sure that the two interpreters ignore such a page. The renderer does not
// write such a page, and the decoder refuses it.
test("the commands of each click in the fixture file are valid, except a page below slide 1", () => {
  let valid = 0;
  let outside = 0;
  for (const each of raw.cases) {
    for (const [kind, , commands] of each.events) {
      if (kind !== "click" || commands === null) {
        continue;
      }
      const list = commands as readonly (readonly unknown[])[];
      const text = JSON.stringify(commands);
      const below = list.some(
        ([name, slide]) => name === "goto_slide" && (slide as number) < 1,
      );
      if (below) {
        assert.throws(() => validateCommands(text), DecodeError, text);
        outside++;
      } else {
        validateCommands(text);
        valid++;
      }
    }
  }
  assert.ok(valid > 0, "the fixture file has no valid click with commands");
  assert.ok(outside > 0, "the fixture file has no page below slide 1");
});
