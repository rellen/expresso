# Show the steps of a proof

This guide shows how to animate a proof one step at a time, with each step of each
β-reduction. The example is the proof that the Y combinator gives a fix point: `Y g` is
equal to `g (Y g)`.

![The proof that Y g is a fix point of g, one step at a time](https://raw.githubusercontent.com/rellen/expresso/media/y-combinator.gif)

The proof is a `math` element with one `line` entity for each line. Each line comes from the
lines before it: `\from` marks a sub-term that comes from a part of an earlier line, and a
copy of that part moves to its place at the step of the line. See
[the math element](../reference/math-element.md#link-a-line-to-an-earlier-line).

## Plan the steps of a β-reduction

A β-reduction replaces each bound variable in the body of a λ with the argument. Show it in
three steps:

| Step | The slide shows |
| --- | --- |
| 1 | The redex: the λ and its argument get a color. |
| 2 | The bound variables: each place of the variable in the body gets the color of the λ. |
| 3 | The new line: the body moves down, and a copy of the argument moves into each hole. |

Each line of the proof stays on the slide, and an old line dims after the step that uses
it. The reason of each line tells what the step does.

## Write the lines

1. Write each line with `line`: its relation, its term in `tex` and its reason in `why`.
2. Give a name with `\part` to each sub-term that a later line uses, such as the argument.
3. Write the body of a λ in parts around its holes, such as `\part{lam1}{(\lambda x.}`
   and `\part{app1}{(x\,x))}`. A copy of the argument then lands in a place that shows no
   bound variable under it. The bound variables need no names.
4. In a later line, write each sub-term that comes from an earlier line with
   `\from{name}{…}`, and the same LaTeX as its source.
5. Write a new symbol, such as a parenthesis that the reduction adds, with no `\from`. It
   fades in with its line.

A link names the nearest earlier line with the name, so a line can take a term from any
line before it. The last line of the example takes `Y g` from the first line.

## Write the steps

1. Give the part of each line, such as `"line3"`, the step at which it shows with `at`.
2. Color a part with `set: [color: "var(--accent)"]`, and dim an old line with `state: :dim`
   in the part of that line.
3. Color each bound variable with one part: `each "f"` and `within "body"` select each `f`
   of the part `body`. See
   [each occurrence of a symbol](../reference/math-element.md#each-occurrence-of-a-symbol).
4. To color a copy, put a `\part` inside its `\from`, such as
   `\from{Yg}{\part{Yg4}{Y\,g}}`, and give that part an `on` entity. A copy takes no
   color from its source.

`for` makes the same part for each item of a list, such as the parts of the last line.

## The example deck

```elixir
defmodule Examples.YCombinator do
  use Expresso

  # The proof that Y g is equal to g (Y g), with each step of each
  # β-reduction. Each line comes from the lines before it: \from marks a
  # sub-term that comes from a part of an earlier line, and a copy of that
  # part moves to its place at the step of the line. The body of each λ is in
  # parts around its holes, so a copy of the argument lands in an empty place.
  # One part with each colors each f of the body of the definition, so the
  # bound variables need no names.

  @accent "var(--accent)"
  @argument "var(--success)"

  css ".small { font-size: 1rem; }"

  slide "Y is a fix point" do
    heading "Y is a fix point"

    math do
      class "small"

      line tex: ~S"\part{Yg}{\part{Y}{Y}\,g}"

      line "=",
        tex: ~S"""
        \part{def}{(\lambda \part{bind}{f}.\,\part{body}{\part{lam1}{(\lambda x.}\,f\,
        \part{app1}{(x\,x))}\,\part{lam2}{(\lambda x.}\,f\,
        \part{app2}{(x\,x))}})}\,\part{arg}{g}
        """,
        why: "the definition of Y"

      line ~S"\to_\beta",
        tex: ~S"""
        \from{lam1}{(\lambda \part{bindx}{x}.}\,\from{arg}{\part{g2}{g}}\,
        \from{app1}{\part{bound}{(x\,x))}}\,
        \part{A}{\from{lam2}{(\lambda x.}\,\from{arg}{g}\,\from{app2}{(x\,x))}}
        """,
        why: "f := g"

      line ~S"\to_\beta",
        tex: ~S"""
        \from{g2}{\part{g3}{g}}\,(\from{A}{(\lambda x.\,g\,(x\,x))}\,
        \from{A}{(\lambda x.\,g\,(x\,x))})
        """,
        why: ~S"x := λx.g (x x)"

      line ~S"=_\beta",
        tex: ~S"\from{g3}{\part{g4}{g}}\,(\from{Yg}{\part{Yg4}{Y\,g}})",
        why: "line 3 =β Y g"

      # Line 1 shows at step 2, line 2 at step 5, line 3 at step 8 and line 4
      # at step 9. An old line dims after the step that uses it.
      part "line2" do
        at from: 2
        on [from: 6], state: :dim
      end

      part "line3" do
        at from: 5
        on [from: 9], state: :dim
      end

      part "line4", at: [from: 8]
      part "line5", at: [from: 9]

      part "Y" do
        on 2, set: [color: @accent]
      end

      part "def" do
        on 2, set: [color: @accent]
      end

      part "bind" do
        on 3..4, set: [color: @accent]
      end

      # The two bound variables: each f of the body.
      part "fs" do
        each "f"
        within "body"
        on 4, set: [color: @accent]
      end

      part "arg" do
        on 3..5, set: [color: @argument]
      end

      # The second β-reduction: λx.g (x x) applied to a copy of itself.
      part "bindx" do
        on 6..7, set: [color: @accent]
      end

      part "bound" do
        on 7, set: [color: @accent]
      end

      part "A" do
        on 6..8, set: [color: @argument]
      end

      # Y g and the copy of Y g in the last line, and the g in front of it.
      for last <- ["Yg", "g4", "Yg4"] do
        part last do
          on [from: 9], set: [color: @argument]
        end
      end
    end
  end
end

Examples.YCombinator
```
