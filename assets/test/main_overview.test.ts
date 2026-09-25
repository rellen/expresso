import { test, before } from "node:test";
import assert from "node:assert/strict";
import { fakePage } from "./page.ts";

// Five slides. Slide 2 has three steps, and slide 3 has two steps. The
// overview has three columns. The tests run in sequence on the same page.
const page = fakePage([1, 3, 2, 1, 1]);
const { body, pages } = page;

before(async () => {
  await import("../src/main.ts");
});

// The pages that have an attribute, as "slide.step".
function pagesWith(name: "thumbnail" | "selected"): string[] {
  return pages
    .filter((each) => each.dataset[name] !== undefined)
    .map((each) => `${each.dataset.slide}.${each.dataset.step}`);
}

function thumbnail(slide: number) {
  const found = pages.find(
    (each) =>
      each.dataset.slide === String(slide) &&
      each.dataset.thumbnail !== undefined,
  );
  assert.ok(found, `no thumbnail for slide ${slide}`);
  return found;
}

test("o shows the last step of each slide, and selects the current slide", () => {
  page.navigate("#2.2");

  assert.equal(page.press("o"), true);

  assert.equal(body.dataset.overview, "true");
  assert.deepEqual(pagesWith("thumbnail"), ["1.1", "2.3", "3.2", "4.1", "5.1"]);
  assert.deepEqual(pagesWith("selected"), ["2.3"]);
  assert.equal(body.style.properties["--overview-columns"], "3");
  assert.equal(body.style.properties["--overview-zoom"], "0.32");
  // The overview does not change the position, so the address stays.
  assert.equal(page.location.hash, "#2.2");
});

test("the arrow keys select a slide, and a slide outside the deck stays unselected", () => {
  page.press("ArrowDown");
  assert.deepEqual(pagesWith("selected"), ["5.1"]);

  assert.equal(page.press("ArrowDown"), false);
  assert.equal(page.press("ArrowRight"), false);
  assert.deepEqual(pagesWith("selected"), ["5.1"]);

  page.press("ArrowUp");
  assert.deepEqual(pagesWith("selected"), ["2.3"]);
  page.press("ArrowRight");
  assert.deepEqual(pagesWith("selected"), ["3.2"]);
  page.press("ArrowLeft");
  assert.deepEqual(pagesWith("selected"), ["2.3"]);

  page.press("End");
  assert.deepEqual(pagesWith("selected"), ["5.1"]);
  page.press("Home");
  assert.deepEqual(pagesWith("selected"), ["1.1"]);
  assert.equal(page.location.hash, "#2.2");
});

test("the overview does not know the keys of the present view", () => {
  for (const key of ["b", "p", "s", "g", "1"]) {
    assert.equal(page.press(key), false, key);
  }
  assert.equal(body.dataset.overview, "true");
  assert.equal(body.dataset.blank, undefined);
});

test("Enter goes to step 1 of the selected slide, and closes the overview", () => {
  page.press("j");
  page.press("j");
  page.press("Enter");

  assert.equal(body.dataset.overview, undefined);
  assert.equal(page.location.hash, "#3.1");
});

test("Escape and o close the overview at the same step", () => {
  for (const key of ["Escape", "o"]) {
    page.press("o");
    page.press("ArrowRight");
    page.press(key);

    assert.equal(body.dataset.overview, undefined, key);
    assert.equal(page.location.hash, "#3.1", key);
  }
});

test("a click on a slide of the overview goes to step 1 of that slide", () => {
  page.press("o");
  page.click({ clientX: 100, on: thumbnail(2) });

  assert.equal(body.dataset.overview, undefined);
  assert.equal(page.location.hash, "#2.1");
});

test("a click or a swipe between the slides of the overview does nothing", () => {
  page.press("o");
  const count = page.written.length;

  page.click(900);
  page.click(100);
  page.swipe({ x: 800, y: 300 }, { x: 600, y: 300 });

  assert.equal(body.dataset.overview, "true");
  assert.equal(page.written.length, count);
  assert.equal(page.location.hash, "#2.1");
});

test("? lists the keys of the overview, and the next key closes only the list", () => {
  page.press("?");
  const panel = page.element("help");
  const texts = panel?.children.map((row) => row.children[1].textContent);
  assert.ok(texts?.includes("Select the next slide"));
  assert.ok(texts?.includes("Step 1 of the selected slide"));
  assert.ok(!texts?.includes("Handout view"));

  page.press("Enter");
  assert.equal(body.dataset.help, undefined);
  assert.equal(body.dataset.overview, "true");
  assert.equal(page.location.hash, "#2.1");
});

test("a click on a slide under the list of keys closes only the list", () => {
  page.press("?");
  page.click({ clientX: 100, on: thumbnail(5) });

  assert.equal(body.dataset.help, undefined);
  assert.equal(body.dataset.overview, "true");
  assert.equal(page.location.hash, "#2.1");
  page.press("o");
});

test("the handout view does not know o", () => {
  page.press("p");
  assert.equal(page.press("o"), false);
  assert.equal(body.dataset.overview, undefined);
  page.press("p");
});
