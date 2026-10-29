# The math element

The `math` element shows a formula in MathML. The browser draws the formula with no script
and no font file. The `tex` option takes the formula in LaTeX, and the render makes the
MathML.

```elixir
slide "the formula" do
  math tex: ~S"E = mc^2"
end
```

The element takes the MathML as its first argument, or the LaTeX in the `tex` option:

```elixir
slide "the formula" do
  math ~S"""
  <math display="block">
    <mi>E</mi><mo>=</mo><mi>m</mi><msup><mi>c</mi><mn>2</mn></msup>
  </math>
  """
end
```

`Expresso.Builder` takes the same argument and option, such as `math(~S"<math>...</math>")` and
`math(tex: ~S"E = mc^2")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | MathML, from `<math>` to `</math>` | The formula. Give this argument or `tex`. |
| `tex` | LaTeX, such as `~S"x^2 + 1"` | The formula. The render makes its MathML with Temml. See [A formula in LaTeX](#a-formula-in-latex). |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## MathML

The text goes into the document as it is. Each browser of the floor of this project
supports MathML Core. Give the `math` tag the attribute `display="block"` for a formula on
its own line.

Use the `~S` sigil for the text, so that Elixir does not change a `\` or a `#{`.

A tool such as Pandoc or Temml makes MathML from LaTeX. Put its output into the element, or
use the `tex` option.

## A formula in LaTeX

The `tex` option takes the formula in LaTeX. The render runs
[Temml](https://temml.org) in Node, and Temml makes the MathML of each formula of the deck in
one run. Temml supports most of the LaTeX of mathematics, such as `\frac`, `\sqrt`,
`\sum`, `\begin{aligned}` and `\text`. Each formula is in display mode, so it is on its own
line.

| Topic | Rule |
| --- | --- |
| Node | The render needs Node on the `PATH`, as for a diagram from Mermaid. `EXPRESSO_NODE` gives a different path. A deck with no `tex` option needs no Node. The project holds its own copy of Temml, so you do not install a package of npm. |
| An error | A formula that Temml cannot read stops the render with the formula and the message of Temml, such as `Unexpected end of input`. |
| The commands that Temml refuses | Temml refuses each command that writes an attribute or reads a file, such as `\id`, `\style` and `\includegraphics`. It allows `\class` and `\data`. |
| The watch mode | The watch mode keeps the MathML of each formula from one render to the next, so a change of one slide runs Temml for the formulas that changed. |

Use the `~S` sigil for the LaTeX, so that Elixir does not change a `\`.

## The parts of a formula

A part is a sub-term of a formula with a name. Two commands of the LaTeX give a name:

| Command | The MathML gets | Use |
| --- | --- | --- |
| `\part{redex}{(\lambda f.\,f)\,g}` | `data-part="redex"` on the sub-term | A part of the formula. |
| `\class{redex}{(\lambda f.\,f)\,g}` | `class="redex"` on the sub-term | A part, and a class for a rule of the `css` option. |

```elixir
slide "the redex" do
  math tex: ~S"\part{redex}{(\lambda \part{bind}{f}.\,f\,x)\,\part{arg}{g}}"
end
```

- A part can hold other parts, such as `bind` and `arg` in `redex` above.
- Two sub-terms can have the same name. They are then one part.
- A name starts with a letter, and it holds only letters, digits, `-` and `_`. The compiler
  refuses a different name.
- The MathML argument can give a part with the attribute `data-part` or `class`.

## The steps of a part

A `part` entity of a `math` element gives a part its steps. It takes the overlay options, as
a part of a diagram does: `at`, `effect` and the `on` entity with `state` and `set`.

```elixir
slide "the redex" do
  math do
    tex ~S"\part{redex}{(\lambda \part{bind}{f}.\,f\,x)\,\part{arg}{g}}"

    part "bind" do
      on [from: 2], set: [color: "var(--accent)"]
    end

    part "arg", at: [from: 3]

    part "redex" do
      on 4, state: :alert
    end
  end
end
```

At step 2 the binder `f` gets the accent color, at step 3 the argument `g` shows, and at
step 4 an outline goes around the whole redex.

A `math` element with a `do` block takes `tex` inside the block, as above. The form
`math tex: ... do` gives the option to the MathML argument, and the compiler refuses it.

| Option | Effect on a part |
| --- | --- |
| `at` | The part shows at these steps, and keeps its space at the other steps. |
| `effect` | The way in which the part shows, such as `:grow` or `:fly_up`. |
| `on ..., state: :dim` | The part dims. |
| `on ..., state: :alert` | An outline goes around the part. |
| `on ..., set: [color: ...]` | The part gets that color. |
| `on ..., set: [x: ..., y: ..., scale: ..., rotate: ..., opacity: ...]` | The part moves, changes its size, turns or fades. |

- A part with the name of two sub-terms changes both.
- The compiler refuses `move_to` on a part of a formula. Issues #473 and #474 plan the moves
  between parts.
- The render stops for a `part` with a name that the formula does not have, and the message
  gives the names of the parts.

## The lines of a derivation

A derivation has a line for each step, and the lines align on their relations, such as `=`
or `→β`. A formula takes its lines in two forms.

### Aligned LaTeX

`\begin{aligned}` aligns the rows of the `tex` option on `&`. Give each row a part, so it can
take steps:

```elixir
slide "the proof" do
  math tex: ~S"""
  \begin{aligned}
    & \part{l1}{(a + b)^2} \\
    \part{l2}{=} & \part{l2}{a^2 + 2ab + b^2}
  \end{aligned}
  """
end
```

A cell of a row cannot be inside a group of a different cell, so a part of a row names each
cell, as `l2` does above.

### The line entity

The `line` entity writes the aligned LaTeX for you. Its first argument is the relation in
LaTeX, the `tex` option is the term, and the `why` option is the reason in a column at the
right.

```elixir
slide "the proof" do
  math do
    reveal true
    line tex: ~S"(a + b)^2"
    line "=", tex: ~S"(a + b)(a + b)", why: "the definition of a square"
    line "=", tex: ~S"a^2 + 2ab + b^2", why: "multiply out"
  end
end
```

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | LaTeX, such as `"="` or `~S"\to_\beta"` | The relation of the line. The first line usually has none. |
| `tex` | LaTeX | The term of the line. |
| `why` | Plain text | The reason of the line. A character such as `&`, `%` or `{` shows as it is. |
| `name` | A name | The name of the part of the line. The default is `line1`, `line2` and so on. |

- Each line is a part with its name, so a `part` entity can give it steps, such as
  `part "line2" do on 3, state: :alert end`. Its options add to the line.
- `reveal true` on the `math` element shows each line at its own step. The first line shows at
  the first step of the element. A `part` of the deck without an `at` option does not take a
  step.
- A `math` element takes line entities, the MathML argument or the `tex` option, and one
  only.

## The math font

The deck option `math_font` gives the font of each `math` element. The document holds the
font as a data URI, so a formula looks the same on each computer and needs no network.

```elixir
defmodule MyTalk do
  use Expresso

  math_font :stix

  slide "the formula" do
    math tex: ~S"\sum_{i=1}^n i = \frac{n(n+1)}{2}"
  end
end
```

| Value | Font | Size in the document |
| --- | --- | --- |
| `:latin_modern` | Latin Modern Math, the font of LaTeX. This is the default. | Approximately 540 kilobytes |
| `:stix` | STIX Two Math, a font in the style of Times. | Approximately 750 kilobytes |
| `:libertinus` | Libertinus Math. | Approximately 460 kilobytes |
| `:noto` | Noto Sans Math, a font without serifs. | Approximately 470 kilobytes |
| `:system` | A math font of the computer that shows the deck. | Approximately 20 kilobytes |

- A document holds the chosen font only when the deck has a `math` element. A deck with no
  formula is not larger.
- The text of `\text{…}` in a formula takes the font of the slide, from the custom property
  `--font-text`. See [the css option](css-option.md).
- `:system` holds no math font. A computer without a math font shows a formula with a font
  for text, and some symbols do not align.
- The style sheet of Temml for each font comes with the font, so its rules for stretched
  accents and arrows fit the font.

## Show the steps of a proof

[Explain a formula step by step](../how-to/explain-a-formula-step-by-step.md) shows the parts
and the lines with example decks. A part cannot move to the place of another part yet. To
move a copy of each symbol of a formula, see
[Show the steps of a proof](../how-to/show-the-steps-of-a-proof.md), which draws the formula
as a diagram.
