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

## Move the argument into each hole

`move_to` moves a part to the place of a different part of the same formula. In this deck,
each copy of the argument starts on the argument and then moves into its hole.

```elixir
defmodule Examples.MathMove do
  use Expresso

  css ".small { font-size: 1rem; }"

  slide "the argument moves into each hole" do
    heading "The argument moves into each hole"

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

      part "arg" do
        on [from: 2], set: [color: "var(--success)"]
        on [from: 4], state: :dim
      end

      part "f1" do
        on [from: 2], set: [color: "var(--accent)"]
      end

      part "f2" do
        on [from: 2], set: [color: "var(--accent)"]
      end

      part "reduced", at: [from: 3]

      part "g1" do
        on 3, move_to: "arg"
        on [from: 3], set: [color: "var(--success)"]
      end

      part "g2" do
        on 3, move_to: "arg"
        on [from: 3], set: [color: "var(--success)"]
      end
    end
  end
end

Examples.MathMove
```

![The holes get a color, then the reduced term shows with each copy of the argument on the argument, then each copy moves into its hole](https://raw.githubusercontent.com/rellen/expresso/media/math-move.gif)

1. At step 2, the argument and the two holes get their colors.
2. At step 3, the reduced term shows. Each copy of the argument is on the argument, so the
   holes of the reduced term are empty.
3. At step 4, each copy moves into its hole, and the argument dims.

The presenter script measures each move in the browser, so the move stays correct with each
font and each size of the window. `examples/animations/math_move.exs` holds the deck. To move
the symbols of a long proof with a layout of your own, see
[Show the steps of a proof](show-the-steps-of-a-proof.md).


## Copy the argument into each hole

A β-reduction keeps its argument and puts a copy of it in the place of each bound variable.
`copy_to` makes one copy of a part for each target, and the part stays at its place.

```elixir
defmodule Examples.MathCopy do
  use Expresso

  css ".small { font-size: 1.25rem; }"

  slide "copy the argument" do
    heading "Copy the argument"

    math do
      class "small"

      line tex: ~S"(\lambda \part{bind}{f}.\,\part{f1}{f}\,(\part{f2}{f}\,x))\,\part{arg}{g}"

      line ~S"\to_\beta",
        tex: ~S"\part{h1}{g}\,(\part{h2}{g}\,x)",
        why: "f := g",
        name: "reduced"

      part "bind" do
        on [from: 2], set: [color: "var(--accent)"]
      end

      for bound <- ["f1", "f2"] do
        part bound do
          on [from: 2], set: [color: "var(--accent)"]
        end
      end

      part "arg" do
        on [from: 2], set: [color: "var(--success)"]
        on 3, copy_to: ["h1", "h2"]
      end

      part "line1" do
        on [from: 4], state: :dim
      end

      part "reduced", at: [from: 3]

      for hole <- ["h1", "h2"] do
        part hole do
          at from: 4
          on [from: 4], set: [color: "var(--success)"]
        end

        part "arg@#{hole}" do
          on [from: 3], set: [color: "var(--success)"]
          on [from: 4], set: [opacity: 0]
        end
      end
    end
  end
end

Examples.MathCopy
```

![The binder, the bound variables and the argument get colors, then a copy of the argument goes into each hole of the reduced term, then the redex dims](https://raw.githubusercontent.com/rellen/expresso/media/math-copy.gif)

1. At step 2, the binder, each bound variable and the argument get their colors.
2. At step 3, the reduced term shows without its two `g`. A copy of the argument fades in on
   the argument and moves into each hole.
3. At step 4, the two `g` of the reduced term show, the copies fade, and the redex dims.

The two holes are parts with `at [from: 4]`, so they show when the copies fade. A `part`
with the name of a copy, such as `"arg@h1"`, gives that copy its options.
`examples/animations/math_copy.exs` holds the deck.


## Use each occurrence of a symbol

A part with `each` names each occurrence of a symbol, such as each `x` of a polynomial. One
entry then colors each occurrence, and one `copy_to` puts a copy of a part in the place of
each occurrence.

```elixir
defmodule Examples.MathEach do
  use Expresso

  # One part names each x of the polynomial, so one entry colors each x, and
  # one copy_to puts the value in the place of each x.

  slide "evaluate a polynomial" do
    heading "Evaluate a polynomial"

    math do
      tex ~S"p(x) = \part{poly}{3 \cdot x^2 + 2 \cdot x + 1}, \quad x = \part{value}{2}"

      # Each x of the polynomial, and not the x of p(x) or of x = 2.
      part "xs" do
        each "x"
        within "poly"
        on [from: 2], set: [color: "var(--accent)"]
        on [from: 3], set: [opacity: 0]
      end

      # At step 3, a copy of the value goes to each x.
      part "value" do
        on [from: 2], set: [color: "var(--success)"]
        on 3, copy_to: ["xs"]
      end

      # The copies of the value, one for each x.
      part "value@xs" do
        on [from: 3], set: [color: "var(--success)"]
      end
    end
  end
end

Examples.MathEach
```

![Each x of the polynomial gets a color, then a copy of the value goes into the place of each x](https://raw.githubusercontent.com/rellen/expresso/media/math-each.gif)

1. At step 1, the polynomial and the value show.
2. At step 2, each `x` of the polynomial and the value get their colors. The `x` of `p(x)`
   and of `x = 2` stay as they are, because `within "poly"` limits the part to the part
   `poly`.
3. At step 3, a copy of the value fades in on the value and moves to the place of each `x`,
   and each `x` fades.

A `part` with the name of the copy, `"value@xs"`, gives each copy its color. The copy to the
occurrence `n` has the name `value@xs-n`. With `bare true`, the part skips a symbol with an
index, such as the `x` of `x_1`. See
[each occurrence of a symbol](../reference/math-element.md#each-occurrence-of-a-symbol).
`examples/animations/math_each.exs` holds the deck.

## Build the next line from the line before

`\from{name}{…}` in a line marks a sub-term that comes from the part `name` of an earlier
line. At the step of the line, a copy of that part moves to its place, so the audience sees
where each sub-term of the new line comes from.

```elixir
defmodule Examples.MathLink do
  use Expresso

  css ".small { font-size: 1.25rem; }"

  slide "build the next line" do
    heading "Build the next line"

    math do
      class "small"
      reveal true

      line tex:
             ~S"(\lambda \part{bind}{f}.\,\part{f1}{f}\,\part{open}{(}\part{f2}{f}\,\part{x}{x)})\,\part{arg}{g}"

      line ~S"\to_\beta",
        tex: ~S"\from{arg}{\part{g1}{g}}\,\from{open}{(}\from{arg}{\part{g2}{g}}\,\from{x}{x)}",
        why: "f := g",
        steps: 2

      for bound <- ["bind", "f1", "f2"] do
        part bound do
          on [from: 1], set: [color: "var(--accent)"]
        end
      end

      for argument <- ["arg", "g1", "g2"] do
        part argument do
          on [from: 1], set: [color: "var(--success)"]
        end
      end
    end
  end
end

Examples.MathLink
```

![The redex has its colors, then a copy of the argument moves into each hole of the next line, then the relation and the reason show](https://raw.githubusercontent.com/rellen/expresso/media/math-link.gif)

1. At step 1, the redex shows, with the binder, the bound variables and the argument in
   their colors.
2. At step 2, a copy of `g` moves into each hole of the second line, and a copy of `(` and
   of `x)` moves down from the body.
3. At step 3, the relation and the reason of the second line show, because the line has
   `steps: 2`.

The body is in parts around its holes, so no bound variable shows under a copy of the
argument. A `\part` inside a `\from`, such as `\part{g1}{g}`, gives the copy a color. To
show a whole proof in this form, see [Show the steps of a proof](show-the-steps-of-a-proof.md).

## Make the next line by a rule

A `rewrite` entity makes the next line from the line before it, so you do not write the new
line. A rule with variables applies an equation, and `replace` with `by_tex` puts a value in
the place of a symbol.

```elixir
defmodule Examples.MathRule do
  use Expresso

  # Two rewrites make the next lines. A rule with variables expands the
  # product, and a substitution puts the value of x into each place.

  slide "apply a rule" do
    heading "Apply a rule"

    math do
      reveal true

      line tex: ~S"k\,(x + h)"

      rewrite rule: {~S"a\,(b + c)", ~S"a \cdot b + a \cdot c"},
              vars: ~w(a b c),
              why: "distribute"

      rewrite replace: "x", by_tex: "2", why: "x := 2"

      # The first line dims when the third line starts.
      part "line1" do
        on [from: 5], state: :dim
      end
    end
  end
end

Examples.MathRule
```

![The product gets a color, then each part of it moves down and the sum fades in, then the value goes into the place of x](https://raw.githubusercontent.com/rellen/expresso/media/math-rule.gif)

Each rewrite takes three steps:

1. The match of the rule, or each occurrence of `x`, gets the accent color.
2. Each kept symbol of the old line moves down to its place in the new line.
3. A copy of each part of the match moves into its place, the new content fades in, and the
   relation and the reason show.

The rule binds `a` to `k`, `b` to `x` and `c` to `h`, so a copy of `k` goes to two places.
The old line needs no names. See
[write the next line by a rewrite](../reference/math-element.md#write-the-next-line-by-a-rewrite).
`examples/animations/math_rule.exs` holds the deck. To show a whole proof in this form, see
[Show the steps of a proof](show-the-steps-of-a-proof.md).

## Make a wide formula fit

A formula is larger than the text of the slide. When the layout check reports that a formula
goes past an edge, give it a class and a smaller size of text, as the deck above does with
`class "small"` and the `css` option. See [Check that a deck fits the screen](check-the-layout.md).

## Choose a math font

The deck option `math_font` gives the font of each formula: `:latin_modern`, the default,
`:stix`, `:libertinus`, `:noto` or `:system`. The document holds the font, so a formula looks
the same on each computer. See [the math font](../reference/math-element.md#the-math-font).
