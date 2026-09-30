import { test } from "node:test";
import assert from "node:assert/strict";
import { commands, parse } from "../src/program.ts";
import { texts } from "./fixtures.ts";

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
    ["blank", "help", "overview", "present", "speaker", "handout"],
  );
  const mode = program.modes[3];
  assert.deepEqual(mode?.keys.get("j"), [
    ["clear", "digits"],
    ["step", 1],
  ]);
  assert.deepEqual(mode?.keys.get(" "), mode?.keys.get("j"));
  assert.deepEqual(mode?.click.get("left_third"), [
    ["clear", "digits"],
    ["step", -1],
  ]);
  assert.equal(mode?.element, false);
  assert.equal(program.modes[2]?.element, true);
});

test("parse throws for a program that the renderer does not write", () => {
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
  ];
  for (const each of texts) {
    assert.throws(
      () => parse(each),
      { message: "The program of the presenter is not valid" },
      each.slice(0, 80),
    );
  }
});

test("commands reads the commands of a page of the overview", () => {
  const program = parse(text);

  assert.deepEqual(
    commands('[["goto_slide",2],["set","overview",false]]', program),
    [
      ["goto_slide", 2],
      ["set", "overview", false],
    ],
  );
  assert.throws(() => commands('[["goto_slide","x"]]', program), {
    message: "The program of the presenter is not valid",
  });
});
