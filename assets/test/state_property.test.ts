// The properties of the code that stays in `state.ts`. The properties of the
// keys and the moves are ExUnit properties in `test/expresso/presenter/`.

import { test } from "node:test";
import assert from "node:assert/strict";
import fc from "fast-check";
import { accepts, columns, side, stamp, swipe, SWIPE } from "../src/state.ts";
import { RUNS } from "./property.ts";

// A time in milliseconds. The small times give two windows the same time.
const time = fc.oneof(fc.nat({ max: 3 }), fc.nat());

test("of two windows at the times p and q, exactly one takes the state of the other", () => {
  fc.assert(
    fc.property(time, time, (p, q) => {
      assert.notEqual(accepts(p, q, false), accepts(q, p, true));
    }),
    { numRuns: RUNS },
  );
});

test("stamp is more than the last time, and not less than the clock", () => {
  fc.assert(
    fc.property(fc.nat(), fc.nat(), (last, now) => {
      const time = stamp(last, now);
      assert.ok(time > last);
      assert.ok(time >= now);
      assert.ok(time === now || time === last + 1);
    }),
    { numRuns: RUNS },
  );
});

test("columns returns the smallest number of columns with as many rows as columns or fewer", () => {
  fc.assert(
    fc.property(fc.integer({ min: 1, max: 100_000 }), (slides) => {
      const width = columns(slides);
      assert.ok(width * width >= slides);
      assert.ok(width === 1 || (width - 1) * (width - 1) < slides);
    }),
    { numRuns: RUNS },
  );
});

test("a click on the left third of a window is on the left third, and each other click is on the right", () => {
  fc.assert(
    fc.property(
      fc
        .integer({ min: 1, max: 4000 })
        .chain((width) =>
          fc.tuple(fc.constant(width), fc.integer({ min: 0, max: width - 1 })),
        ),
      ([width, x]) => {
        assert.equal(side(x, width), x < width / 3 ? "left_third" : "right");
      },
    ),
    { numRuns: RUNS },
  );
});

test("a swipe has the direction of the finger, a short or a vertical movement is not a swipe, and the opposite swipe has the other direction", () => {
  fc.assert(
    fc.property(
      fc.integer({ min: -500, max: 500 }),
      fc.integer({ min: -500, max: 500 }),
      (dx, dy) => {
        const result = swipe(dx, dy);
        const opposite = swipe(-dx, dy);
        if (Math.abs(dx) < SWIPE || Math.abs(dx) <= Math.abs(dy)) {
          assert.equal(result, undefined);
          assert.equal(opposite, undefined);
        } else {
          assert.equal(result, dx < 0 ? "left" : "right");
          assert.equal(opposite, dx < 0 ? "right" : "left");
        }
      },
    ),
    { numRuns: RUNS },
  );
});
