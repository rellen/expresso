# Formulas with parts

This document gives the design for a `math` element that takes LaTeX and gives a name to
each part of the formula, and the record of its progress. A step can then color, dim or move
one part of a formula. The document records ten decisions, and each is settled. Issue #472
holds the same plan.

## The problem

A talk about mathematics or about a program often explains a formula one part at a time: the
term that changes, the variable that a rule binds, or the line of a proof that follows from
the line before it. The `math` element cannot do this:

- A step can show, hide or change a whole `math` element, but not one symbol or one sub-term
  in it.
- The author must write MathML by hand. One line of the proof in
  `examples/animations/y_combinator.exs` takes approximately 15 lines of MathML.
- The theme gives no math font. A formula mixes the font of the system for `mi` with a serif
  font for `mtext`.
- Two lines of a proof do not align on their relation, such as `=` or `→β`.

The example deck `examples/animations/y_combinator.exs` therefore draws its terms as an SVG
file, with one `text` for each symbol in a cell of one width. The spaces are wrong, and a
script of 150 lines writes the file.

## The constraints

- The output stays one HTML file. The render makes the MathML, and the presenter script
  calculates no layout.
- A formula and each of its parts obey the overlay contract: `at`, `on`, `effect`, `class`
  and `morph`. See `docs/overlays.md`.
- A deck with no LaTeX needs no Node, and the MathML argument of `math` stays as it is.
- The handout view and paper show the last step, as for each other element.
- A screen reader reads the MathML of the formula.
- The theme gives each color, so each theme and its dark variant work.

## An example

```elixir
slide "the redex" do
  math tex: ~S"""
  \part{redex}{(\lambda \part{bind}{f}.\,(\lambda x.\part{f1}{f}\,(x\,x))\,
    (\lambda x.\part{f2}{f}\,(x\,x)))\,\part{arg}{g}}
  """ do
    part "bind" do
      on [from: 2], set: [color: "var(--accent)"]
    end

    part "arg" do
      on [from: 2], set: [color: "var(--success)"]
    end

    part "f1" do
      on [from: 3], set: [color: "var(--accent)"]
    end

    part "f2" do
      on [from: 3], set: [color: "var(--accent)"]
    end
  end
end
```

At step 2, the binder `f` and the argument `g` get their colors. At step 3, the two places of
`f` in the body get the color of the binder.

A derivation with aligned lines takes a `line` entity for each line:

```elixir
math do
  reveal true

  line tex: ~S"Y\,g"
  line "=", tex: ~S"(\lambda f.\,(\lambda x.f\,(x\,x))\,(\lambda x.f\,(x\,x)))\,g",
    why: "the definition of Y"
  line ~S"\to_\beta", tex: ~S"(\lambda x.g\,(x\,x))\,(\lambda x.g\,(x\,x))", why: "f := g"
end
```

## The decisions

| Number | Question | Decision |
| --- | --- | --- |
| 1 | The engine | Temml in Node. The project holds a copy of `temml.min.js` in `priv/temml/`, as it holds Pele in `priv/pele/`. A converter of a subset of LaTeX in Elixir can come later, when Node at render time is a problem. |
| 2 | The source | The option `tex` of `math` takes LaTeX. A `math` element takes one source: the MathML argument, `tex` or `line` entities. |
| 3 | The runs of Node | One run of Node for each render makes the MathML of each formula of the deck. The watch mode keeps the MathML of each source in a cache, so a change of one slide runs Node for the formulas that changed. |
| 4 | The names of the parts | `\part{name}{…}` gives a name to a sub-term. `\class{name}{…}` of Temml also names a part. A `part` entity of `math` names one of the two. |
| 5 | A part | A `part` entity of `math` takes the overlay options of a part of a diagram: `at`, `effect` and `on` with `state` and `set`. `move_to` does not apply. Issues #473 and #474 plan the moves between parts. |
| 6 | The math font | The deck option `math_font` takes `:latin_modern`, the default, `:stix`, `:libertinus`, `:noto` or `:system`. The document holds the chosen font only, and only when the deck has a `math` element. `:system` holds no font. |
| 7 | The text in a formula | The text of `\text{…}`, an `mtext`, uses the font of the slide. A symbol uses the math font. |
| 8 | Lines | `\begin{aligned}` in the source aligns lines on `&`. The `line` entity takes a relation, the LaTeX of a term and a reason, and the render writes one `aligned` formula. Each line is a part with the name `line1`, `line2` and so on, and `reveal true` shows each line at its own step. |
| 9 | The tests | A new tag `:temml` marks each test that runs Node. `mix test` excludes it, and the command of the graph tools also runs it. A file of fixtures holds the MathML of the sources of the other tests, and a test with the tag `:temml` makes sure that the fixtures agree with Temml. |
| 10 | The stack and the examples | Nine pull requests. The guide shows new example decks of mathematics. `examples/animations/y_combinator.exs` keeps its SVG file until issues #473 and #474 add the moves. |

## The design

- **The copy of Temml.** `priv/temml/` holds `temml.min.js`, its license, its version in
  `package.json` and a script `render.mjs`. The `package.json` of the project names the same
  version, so Dependabot gives a pull request for a new version, and a test makes sure that
  the two versions agree.
- **The run.** `Expresso.Element.Math.Tex` collects the LaTeX of each `math` element of the
  deck, writes them into a private directory, and runs `render.mjs` with Node, through
  `Expresso.Element.Diagram.Tool`. `EXPRESSO_NODE` gives the path of Node. The script
  writes the MathML of each source, or the message of Temml for a source that it cannot
  read. The render then stops with the slide, the source and the message.
- **The options of Temml.** `displayMode` is true, and `trust` allows `\class` and `\data`
  only. `annotate` is false, so the MathML holds no copy of the LaTeX.
- **The parts.** Before the run, the render replaces `\part{name}{…}` with
  `\data{part=name}{…}`, so the MathML gets `data-part="name"` on the `mrow` of the sub-term.
  A `part` entity finds its element by `data-part`, or by a class of `\class`. The render
  writes the overlay attributes of the part on that element, as it does for a part of a
  diagram. The compiler refuses a part with a name that the formula does not have.
- **The style of a part.** The theme applies `color`, `opacity` and `transform` to an `mrow`.
  Chromium 141 draws each of them on an element of MathML.
- **The fonts.** `priv/fonts/math/` holds a `woff2` file of each font and its license, and
  `Temml.woff2` for the few glyphs that Temml takes from its own font. The renderer writes a
  `@font-face` rule with a data URI of the chosen file, only in a document with a `math`
  element, and the theme sets the `font-family` of `math`.
- **The lines.** The `line` entity writes `\begin{aligned}`, a row for each line, the
  relation after `&`, and the reason after `&&` in `\text{…}`. Each row goes into
  `\part{lineN}{…}`.
- **The handout.** The handout view shows the last step, as for each other element.
- **The checks.** The layout check measures a `math` element as it measures each other
  element. A formula that is wider than its slide fails the check.
- `docs/reference/math-element.md` gives the options. A how-to guide gives the tasks, with
  example decks and their GIFs.

## The stack

1. This document.
2. The copy of Temml in `priv/temml/`, the script and the run in Node.
3. The option `tex` of `math`, its errors and the cache of the watch mode.
4. The option `math_font` and the five fonts. The text of a formula in the font of the slide.
5. `\part` and `\class`: the names of the parts in the MathML.
6. The `part` entity in `math`, with `at`, `effect` and `on`.
7. The lines: `\begin{aligned}` in the guide, and the `line` entity with `reveal`.
8. The handout, the screen reader and the layout check for the parts.
9. The guide, the example decks and their GIFs.

## The progress

| Pull request | State |
| --- | --- |
| 1. This document | Done |
| 2. Temml and the run in Node | Done. `Expresso.Element.Math.Tex.render!/1` makes the MathML of a list of sources in one run, and returns the message of Temml for a source that it cannot read. `Expresso.Element.Diagram.Tool` takes a subject for its messages, such as "the formulas of the deck". Temml 0.14 has no `\href`, and it refuses `\id`, `\style` and `\includegraphics`. |
| 3. The option `tex` | To do |
| 4. The fonts | To do |
| 5. The names of the parts | To do |
| 6. The `part` entity | To do |
| 7. The lines | To do |
| 8. The handout, the screen reader and the layout check | To do |
| 9. The guide, the example decks and their GIFs | To do |
