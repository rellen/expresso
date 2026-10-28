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

## Show the steps of a proof

To move a copy of each symbol of a formula, see
[Show the steps of a proof](../how-to/show-the-steps-of-a-proof.md). A `math` element cannot
change one symbol at a step, so that guide draws the formula as a diagram.
