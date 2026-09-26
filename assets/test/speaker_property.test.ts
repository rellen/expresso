import { test } from "node:test";
import assert from "node:assert/strict";
import fc from "fast-check";
import { clock, describe, left, pace, talkLength } from "../src/speaker.ts";
import type { Pace } from "../src/speaker.ts";
import { maxStep } from "../src/state.ts";
import { reachable, RUNS } from "./property.ts";

// The seconds of a text such as `1:05:07`, `12:34 left` or `+0:30 over`.
function seconds(text: string): number {
  const match = /(\d+(?::\d\d)+)/.exec(text);
  assert.ok(match, text);
  return (match[1] ?? "")
    .split(":")
    .reduce((total, part) => total * 60 + Number(part), 0);
}

// A value of the attribute or of the address parameter.
const value: fc.Arbitrary<string> = fc.oneof(
  fc.string(),
  fc.integer({ min: -100, max: 600 }).map(String),
  fc.double().map(String),
  fc.constantFrom("", " 5 ", "0x10", "Infinity", "-Infinity", "NaN", "1e400"),
);

test("clock gives m:ss below one hour, h:mm:ss from one hour, and 0:00 for a time less than zero", () => {
  fc.assert(
    fc.property(
      fc.double({ min: -1e7, max: 1e8, noNaN: true }),
      (milliseconds) => {
        const text = clock(milliseconds);
        const whole = Math.max(0, Math.floor(milliseconds / 1000));
        assert.equal(seconds(text), whole);
        assert.match(text, whole < 3600 ? /^\d+:\d\d$/ : /^\d+:\d\d:\d\d$/);
      },
    ),
    { numRuns: RUNS },
  );
});

test("the timer and the time left together give the length of the talk", () => {
  fc.assert(
    fc.property(
      fc
        .integer({ min: 1, max: 4 * 3600 })
        .chain((length) =>
          fc.tuple(
            fc.constant(length),
            fc.double({ min: 0, max: length * 1000, noNaN: true }),
          ),
        ),
      ([length, elapsed]) => {
        const total = length * 1000;
        assert.equal(
          seconds(clock(elapsed)) + seconds(left(elapsed, total)),
          length,
        );
      },
    ),
    { numRuns: RUNS },
  );
});

test("after the end of the talk, left gives the time after the end", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: 1, max: 4 * 3600 * 1000 }),
      fc.integer({ min: 1, max: 3600 * 1000 }),
      (total, after) => {
        assert.equal(left(total + after, total), `+${clock(after)} over`);
      },
    ),
    { numRuns: RUNS },
  );
});

test("talkLength gives null or a positive, finite length, and the address parameter replaces the attribute", () => {
  fc.assert(
    fc.property(
      fc.option(value, { nil: undefined }),
      fc.option(value, { nil: null }),
      (attribute, parameter) => {
        const length = talkLength(attribute, parameter);
        assert.ok(
          length === null || (length > 0 && Number.isFinite(length)),
          String(length),
        );
        const fromParameter = talkLength(undefined, parameter);
        if (fromParameter !== null) {
          assert.equal(length, fromParameter);
        }
      },
    ),
    { numRuns: RUNS },
  );
});

test("a later time or fewer steps done never give a better pace", () => {
  const rank: Record<Pace, number> = { on: 0, behind: 1, over: 2 };
  const time = fc.integer({ min: 0, max: 7200 * 1000 });
  const part = fc.double({ min: 0, max: 1, maxExcluded: true, noNaN: true });
  fc.assert(
    fc.property(
      time,
      time,
      fc.integer({ min: 1, max: 3600 * 1000 }),
      part,
      part,
      (a, b, total, x, y) => {
        const [early, late] = a <= b ? [a, b] : [b, a];
        const [less, more] = x <= y ? [x, y] : [y, x];
        assert.ok(
          rank[pace(early, total, more)] <= rank[pace(late, total, more)],
        );
        assert.ok(
          rank[pace(early, total, more)] <= rank[pace(early, total, less)],
        );
        assert.equal(pace(late, total, less) === "over", late > total);
      },
    ),
    { numRuns: RUNS },
  );
});

test("describe gives the slide, a step part only for a slide with more than one step, and a part for a black screen", () => {
  fc.assert(
    fc.property(reachable, fc.boolean(), ([deck, state], blank) => {
      const text = describe({ ...state, blank }, deck);
      const steps = maxStep(state.slide, deck);
      assert.ok(text.startsWith(`Slide ${state.slide} of ${deck.slides}`));
      assert.equal(
        text.includes(`, step ${state.step} of ${steps}`),
        steps > 1,
      );
      assert.equal(text.endsWith(", black screen"), blank);
    }),
    { numRuns: RUNS },
  );
});
