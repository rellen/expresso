# Show the steps of a proof

This guide shows how to animate a proof one step at a time, with each step of each
β-reduction. The example is the proof that the Y combinator gives a fix point: `Y g` is
equal to `g (Y g)`.

![The proof that Y g is a fix point of g, one step at a time](https://raw.githubusercontent.com/rellen/expresso/media/y-combinator.gif)

The proof is a `math` element with one `line` entity for the first line. A `rewrite` entity
unfolds the definition of `Y`, a `reduce` entity makes each β-reduction, and a second
`rewrite` folds the last line. You write no line after the first by hand. See
[the math element](../reference/math-element.md#reduce-a-λ-term).

## The steps of a reduction

A β-reduction replaces each bound variable in the body of a λ with the argument. A `reduce`
shows it in four steps:

| Step | The slide shows |
| --- | --- |
| 1 | The λ with its variable gets the color `--binder`, and the argument gets the color `--argument`. |
| 2 | Each bound variable gets the color `--binder`. |
| 3 | The rest of the body moves down from the old line to the new line. |
| 4 | A copy of the argument moves into the place of each bound variable, and the relation and the reason show. |

A `rewrite` takes three steps: its occurrences get a color, the kept symbols move down, and
the new content moves into its place. Each line of the proof stays on the slide, and an old
line dims when the line after the next one starts. The reason of each line tells what the
step does.

## Write the lines

1. Write the first line with `line`. Give a name with `\part` only to a sub-term that a later
   step copies, such as `Y`.
2. Unfold a definition with `replace` and `by_tex`. The definition needs no names.
3. Write each β-reduction with `reduce :leftmost`. The render finds the leftmost outermost
   redex, its bound variables and its argument, and the reason `x := argument`.
4. Fold a term back with a rule. In the example, the argument of `g` is a term applied to
   itself, so the rule `a\,a` with the variable `a` matches it. The right side
   `\use{Y}\,g` takes a copy of `Y` from the first line.

A reduction stops the render for a capture: a λ of the body that would bind a free variable of
the argument. Give that λ a different variable.

## Write the steps

1. Give the math element `reveal true`. The first line takes one step, a rewrite takes
   three, and a reduction takes four. The option `steps` of each one puts its phases
   together.
2. Dim an old line with `state: :dim` in the part of that line, such as `"line2"`.

A reduction and a rewrite give their parts colors themselves, so the deck needs no color of
its own.

## The example deck

```elixir
defmodule Examples.YCombinator do
  use Expresso

  # The proof that Y g is equal to g (Y g), with each step of each
  # β-reduction. Only the first line is written by hand. A rewrite unfolds
  # the definition of Y, each reduce makes the next line by one β-reduction
  # of the leftmost outermost redex, and a rule folds the last line. The
  # definition of Y needs no names, because each reduce finds the λ, the
  # bound variables and the argument of its redex.

  css ".small { font-size: 1rem; }"

  slide "Y is a fix point" do
    heading "Y is a fix point"

    math do
      class "small"
      reveal true

      line tex: ~S"\part{Y}{Y}\,g"

      rewrite "=",
        replace: "Y",
        by_tex: ~S"(\lambda f.\,(\lambda x.\,f\,(x\,x))\,(\lambda x.\,f\,(x\,x)))",
        why: "the definition of Y"

      reduce :leftmost
      reduce :leftmost

      # The argument of g is a term applied to itself: the line 3.
      rewrite ~S"=_\beta",
        rule: {~S"a\,a", ~S"\use{Y}\,g"},
        vars: ["a"],
        why: "line 3 =β Y g"

      # An old line dims when the line after the next one starts.
      for {line, step} <- [{"line1", 5}, {"line2", 9}, {"line3", 13}] do
        part line do
          on [from: step], state: :dim
        end
      end
    end
  end
end

Examples.YCombinator
```
