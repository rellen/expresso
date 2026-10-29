# Explain a formula step by step

This guide shows how to write a formula in LaTeX, give a name to its parts, and color, show
or outline each part at its own step. It also shows a derivation with a line at each step.
For each option, see [the math element](../reference/math-element.md).

![The discriminant of the quadratic formula gets a color, and an outline goes around the denominator](https://raw.githubusercontent.com/rellen/expresso/media/math-parts.gif)

## Write a formula in LaTeX

Give the LaTeX to the `tex` option of a `math` element. Use the `~S` sigil, so that Elixir
does not change a `\`:

```elixir
slide "the formula" do
  math tex: ~S"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"
end
```

The render runs [Temml](https://temml.org) in Node, so the computer that renders the deck
needs Node on the `PATH`. Expresso holds its own copy of Temml, so you do not install a
package of npm.

## Color a part of a formula at a step

1. Give a name to each sub-term that changes, with `\part{name}{...}`.
2. Put the LaTeX in a `tex` call inside the block of the `math` element.
3. Add a `part` entity with that name, and give it `at`, `effect` or `on` entities.

```elixir
defmodule Examples.MathParts do
  use Expresso

  slide "the quadratic formula" do
    heading "The quadratic formula"

    math do
      tex ~S"x = \frac{-b \pm \sqrt{\part{disc}{b^2 - 4ac}}}{\part{den}{2a}}"

      part "disc" do
        on [from: 2], set: [color: "var(--accent)"]
      end

      part "den" do
        on 3, state: :alert
      end
    end
  end
end

Examples.MathParts
```

At step 2 the discriminant gets the accent color, and at step 3 an outline goes around the
denominator. A part takes `set: [color: ...]`, `state: :dim`, `state: :alert`, `at` for a
part that shows later, and `set: [x: ..., y: ...]` for a part that moves.

## Show a derivation line by line

1. Give the `math` element a `line` entity for each line.
2. Give each line its relation as the first argument, and its term in `tex`.
3. Give a reason in `why`, as plain text.
4. Add `reveal true` to show each line at its own step.

```elixir
defmodule Examples.MathLines do
  use Expresso

  slide "complete the square" do
    heading "Complete the square"

    math do
      reveal true
      line tex: ~S"x^2 + 6x + 5 = 0"
      line ~S"\iff", tex: ~S"x^2 + 6x + 9 = 4", why: "add 4"
      line ~S"\iff", tex: ~S"(x + 3)^2 = 4", why: "a square"
      line ~S"\iff", tex: ~S"x + 3 = \pm 2", why: "a root"
      line ~S"\iff", tex: ~S"x = -1 \text{ or } x = -5"
    end
  end
end

Examples.MathLines
```

![The derivation of a quadratic equation, one line at each step](https://raw.githubusercontent.com/rellen/expresso/media/math-lines.gif)

The lines align on their relations, and the reasons are in a column at the right. Each line
is a part with the name `line1`, `line2` and so on, so a `part` entity with that name can
give it an `on` entity.

## Mark the parts of a step of a proof

A line can hold parts of its own, and the `name` option gives the part of the line a name.
This deck marks each part of one β-reduction:

```elixir
defmodule Examples.MathRedex do
  use Expresso

  css ".small { font-size: 1rem; }"

  slide "a beta reduction" do
    heading "A beta reduction"

    math do
      class "small"

      line tex: ~S"""
           (\lambda \part{bind}{f}.\,(\lambda x.\part{f1}{f}\,(x\,x))\,
           (\lambda x.\part{f2}{f}\,(x\,x)))\,\part{arg}{g}
           """

      line ~S"\to_\beta",
        tex: ~S"(\lambda x.\part{g1}{g}\,(x\,x))\,(\lambda x.\part{g2}{g}\,(x\,x))",
        why: "f := g",
        name: "reduced"

      part "bind" do
        on [from: 2], set: [color: "var(--accent)"]
      end

      part "arg" do
        on [from: 2], set: [color: "var(--success)"]
      end

      part "f1" do
        on 3, set: [color: "var(--accent)"]
      end

      part "f2" do
        on 3, set: [color: "var(--accent)"]
      end

      part "reduced", at: [from: 4]

      part "g1" do
        on 4, set: [color: "var(--success)"]
      end

      part "g2" do
        on 4, set: [color: "var(--success)"]
      end
    end
  end
end

Examples.MathRedex
```

![The binder and the argument get colors, then the bound variables, then the reduced term shows with the argument in each place](https://raw.githubusercontent.com/rellen/expresso/media/math-redex.gif)

1. At step 2, the binder `f` and the argument `g` get their colors.
2. At step 3, each `f` that the binder binds gets the color of the binder.
3. At step 4, the reduced term shows, with `g` in the color of the argument.

A part cannot move to the place of another part yet. To move a copy of the argument into each
hole, see [Show the steps of a proof](show-the-steps-of-a-proof.md). Issues #473 and #474
plan the moves.

## Make a wide formula fit

A formula is larger than the text of the slide. When the layout check reports that a formula
goes past an edge, give it a class and a smaller size of text, as the deck above does with
`class "small"` and the `css` option. See [Check that a deck fits the screen](check-the-layout.md).

## Choose a math font

The deck option `math_font` gives the font of each formula: `:latin_modern`, the default,
`:stix`, `:libertinus`, `:noto` or `:system`. The document holds the font, so a formula looks
the same on each computer. See [the math font](../reference/math-element.md#the-math-font).
