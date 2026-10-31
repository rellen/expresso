# Links between the lines of a derivation

This document gives the design for a link from a sub-term of a line of a derivation to the
sub-term of an earlier line that it comes from. At the step of the new line, each linked
sub-term moves from its place in the earlier line to its place in the new line. The
document also records the progress of the work. It records ten decisions, and each is
settled. Issue #474 holds the same plan.

## The problem

Each new line of a derivation comes from an earlier line. The body of a λ drops one line,
and the argument goes into each hole. A `math` element with `line` entities shows each line
at its own step, but each line fades in as a whole, so the audience does not see where its
parts come from.

The copies of `docs/part-copies.md` can show it, and `examples/animations/y_combinator.exs`
uses them. The author must then:

1. Draw each line in an SVG file with an `id` on each symbol, with a script.
2. Find the source and the target of each move, and write one `copy` for each.
3. Write one `part` for each symbol or group that moves. The proof has approximately 30
   parts.

A change of one line changes the places of each line after it.

## The constraints

- The output stays one HTML file.
- A link obeys the overlay contract of `docs/overlays.md`. It uses the copies of
  `docs/part-copies.md` and the measure of `move_to` in `assets/src/move.ts`.
- The browser lays out the MathML, so the presenter script measures each place. The render
  does not lay out a formula.
- A browser with no script shows each line complete at its step.

## An example

```elixir
math do
  reveal true

  line tex: ~S"(\lambda f.\,\part{body}{f\,(f\,x)})\,\part{arg}{g}"

  line ~S"\to_\beta",
    tex: ~S"\from{body}{\from{arg}{g}\,(\from{arg}{g}\,x)}",
    why: "f := g"
end
```

At step 2, the second line shows. The relation and the reason fade in, the body moves down
from the first line, and a copy of `g` moves into each hole. The first line stays.

## The decisions

| Number | Question | Decision |
| --- | --- | --- |
| 1 | The element | The `line` entities of `math` take the links. The math element gives each line a relation, a term, a reason, a name and a step, so a new derivation element is not necessary. |
| 2 | The form of a link | `\from{name}{…}` in the LaTeX of a line marks a sub-term that comes from the part `name` of an earlier line. |
| 3 | The reach of a link | A link names a part of the nearest earlier line that has a part with that name. A line can thus take a term from two lines before it, as `Y g` of the first line in the last line of the Y combinator. |
| 4 | The steps of a line | By default, at the step of a line, each linked sub-term moves and the other symbols of the line fade in together. The option `steps: 2` of a `line` entity moves the linked sub-terms at the first step and shows the other symbols at the next step. |
| 5 | The earlier lines | An earlier line does not change at the step of a new line. A `part` entity with the name of the line can dim it, as before. |
| 6 | The copies | Each `\from` makes one copy of the source with the copies of #473. Two `\from` with one name make two copies, and the source stays at its place. |
| 7 | The linked sub-terms | A linked sub-term of the new line is the place of its copy. The copy stays on it at each later step, and the script hides the sub-term under it. A browser with no script shows the sub-term, so the line is complete. |
| 8 | The names in a linked sub-term | A `\part` inside a `\from` names the sub-term and its copy, so a `part` entity changes what shows. |
| 9 | The layout and the morph | The presenter script measures each place, as for `move_to`. The moves are inside one element, so they need no morph between slides. |
| 10 | The stack and the examples | Six pull requests. `examples/animations/y_combinator.exs` becomes a `math` element with `line` entities and links, so its SVG file and its script go away. The how-to guide gets an example of one β-reduction with a GIF. |

## The design

- **The macro.** `priv/temml/render.mjs` gives Temml the macro `\from`, which becomes
  `\data{from=name}{…}`. The MathML of the sub-term gets `data-from="name"`.
  `Expresso.Element.Math.check/1` refuses a name that `\data` cannot read, as for `\part`.
- **The lines.** Each line of a math element is the part `line1`, `line2` and so on, or the
  name of its `name` option. An element of the MathML belongs to the line of its nearest
  ancestor with the name of a line.
- **The links.** At render, `Expresso.Element.Math.place/1` finds each element with
  `data-from` and the line of that element. It gives the element a name of its own, and it
  finds the source: the elements with the name in the nearest earlier line. The render
  stops for a name with no source.
- **The copies.** For each link, the render makes a copy part as `Expresso.Element.Copy`
  does, from the source elements of that line only. The copy has the steps of the line,
  and it moves to the linked sub-term. Its `math` element after the formula holds the
  source elements.
- **The steps.** With `steps: 2`, the copies have the first step of the line, and the other
  symbols of the line, its relation and its reason have the next step. The line then takes
  two steps of the counter of `reveal`.
- **The hidden sub-terms.** `assets/src/move.ts` gives each placed copy `data-placed`. The
  style sheet hides a linked sub-term when the copy on it has `data-placed`.
- **The names inside a link.** The copy of a linked sub-term also gets the names of the
  `\part` entities inside it, on an inner element, so the overlay attributes of a `part`
  entity reach the copy.

## The stack

Each pull request is based on the one before it.

1. This document.
2. The macro `\from`, the names and their checks.
3. The copies and the moves of the links.
4. The option `steps` of a line, and the names inside a link.
5. `examples/animations/y_combinator.exs` as a math element with links.
6. The guide, an example of one β-reduction and its GIF.

## The progress

| Pull request | State |
| --- | --- |
| 1. This document | Done |
| 2. The macro `\from` and its names | Done. `priv/temml/render.mjs` gives Temml the macro `\from`, which becomes `\data{from=name}{…}`. `Expresso.Element.Math.check/1` reads the name of each `\from` as the name of a part. It refuses `\from` in a math element without `line` entities and in the first line, because no line comes before it. A link does nothing at render until pull request 3. |
| 3. The copies and the moves of the links | Done. `Expresso.Element.Math.Links.place/1` runs in `Expresso.Element.Math.place/1`. It gives the linked sub-term number `n` the class `link-n`, and each source element in the line `j` the class `from-j-name`, so a copy has its source in one line only. Each link gets a copy part with `covers`, and the copy of #473 does the rest. `check/1` keeps the names of the lines in the new field `line_names`. A line with a link and no steps stops the render, because its copy has no step. `assets/src/move.ts` gives each linked sub-term under a placed copy `data-covered`, and the style sheet hides it. |
| 4. The option `steps` and the names inside a link | Done. With `steps: 2`, `check/1` puts an `on` entity with `:next` last in the part of the line, so the line takes one more step of the counter of `reveal`. `Expresso.Element.Math.Links.place/1` reads the step of that entity and removes it: the line shows from that step, and its copies keep the first step. A `\part` inside a `\from` puts its overlay attributes on an element around the symbols of the copy. |
