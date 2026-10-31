# Show the steps of a proof

This guide shows how to animate a proof one step at a time, with each step of each
β-reduction. The example is the proof that the Y combinator gives a fix point: `Y g` is
equal to `g (Y g)`.

![The proof that Y g is a fix point of g, one step at a time](https://raw.githubusercontent.com/rellen/expresso/media/y-combinator.gif)

The proof is a `math` element with one `line` entity for the first line and one `rewrite`
entity for each next line. A rewrite makes its line from the line before it by a
substitution, so you write no line after the first by hand. See
[the math element](../reference/math-element.md#write-the-next-line-by-a-rewrite).

## The steps of a rewrite

A β-reduction replaces each bound variable in the body of a λ with the argument. A rewrite
shows it in three steps:

| Step | The slide shows |
| --- | --- |
| 1 | Each bound variable gets the accent color, and the argument gets the color of success. |
| 2 | The rest of the body moves down from the old line to the new line. |
| 3 | A copy of the argument moves into the place of each bound variable, and the relation and the reason show. |

Each line of the proof stays on the slide, and an old line dims when the line after the next
one starts. The reason of each line tells what the step does.

## Write the lines

1. Write the first line with `line`, and give a name with `\part` to each sub-term that a
   rewrite uses, such as `Y` and `g`.
2. Unfold a definition with `replace` and `by_tex`. The LaTeX of `by_tex` names the parts
   that the next rewrites use: the binder `lam`, the body `body`, the inner body `bodyx`
   and the argument `arg`.
3. Write a β-reduction with `replace` for the bound variable, `within` for the body, `by`
   for the argument and `drop` for the λ, its parenthesis and the argument.
4. Write a step that folds a term back with a template: `to` with `\use{name}`, such as
   `(\use{Y}\,\use{g})`.

A rewrite keeps the names of the parts that it does not replace, so a later rewrite can use
`bodyx` or `pair` of a line that a rewrite made. `by` and `\use` take the part from the
nearest line that has it, so the last line takes `Y` from the first line.

## Write the steps

1. Give the math element `reveal true`. The first line takes one step, and each rewrite
   takes three.
2. Dim an old line with `state: :dim` in the part of that line, such as `"line2"`.

A rewrite colors the occurrences and the source of `by` itself, so the deck needs no color
of its own.

## The example deck

```elixir
defmodule Examples.YCombinator do
  use Expresso

  # The proof that Y g is equal to g (Y g), with each step of each
  # β-reduction. Only the first line is written by hand. Each rewrite makes
  # the next line: the occurrences get a color, the kept symbols move down,
  # and a copy of the new content moves into each place. The definition of Y
  # names the parts that the later rewrites use.

  css ".small { font-size: 1rem; }"

  slide "Y is a fix point" do
    heading "Y is a fix point"

    math do
      class "small"
      reveal true

      line tex: ~S"\part{Y}{Y}\,\part{g}{g}"

      rewrite "=",
        replace: "Y",
        by_tex: ~S"""
        \part{lam}{(\lambda f.}\,\part{body}{\part{lamx}{(\lambda x.}\,\part{bodyx}{f\,
        \part{pair}{(x\,x)}}\part{closex}{)}\,\part{arg}{(\lambda x.\,f\,(x\,x))}}\part{close}{)}
        """,
        why: "the definition of Y"

      rewrite ~S"\to_\beta",
        replace: "f",
        within: "body",
        by: "g",
        drop: ["lam", "close", "g"],
        why: "f := g"

      rewrite ~S"\to_\beta",
        replace: "x",
        within: "bodyx",
        by: "arg",
        drop: ["lamx", "closex", "arg"],
        why: ~S"x := λx.g (x x)"

      rewrite ~S"=_\beta", replace: "pair", to: ~S"(\use{Y}\,\use{g})", why: "line 3 =β Y g"

      # An old line dims when the line after the next one starts.
      for {line, step} <- [{"line1", 5}, {"line2", 8}, {"line3", 11}] do
        part line do
          on [from: step], state: :dim
        end
      end
    end
  end
end

Examples.YCombinator
```
