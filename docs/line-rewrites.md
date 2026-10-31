# The next line by a rewrite

This document gives the design for a `rewrite` entity of a derivation. The entity makes the
next line from a line before it by a substitution or by a rule, so the author does not write
the new line by hand. The render then writes the new line, its links and its copies. The
document also records the progress of the work. It records ten decisions, and each is
settled. Issue #478 holds the same plan.

## The problem

With the links of `docs/line-links.md`, each new line of a derivation tells which of its
parts come from the line before it. The author must still write the whole new line. For a
substitution, the new line follows from the old line by a rule, so the author writes the
same information two times.

Many talks make a substitution:

- Put a value into a formula, such as `r := 3` in `A = πr²`.
- Unfold a definition, such as `Y` in `examples/animations/y_combinator.exs`.
- Apply an equation as a rule, such as `a (b + c) = a b + a c`.
- Replace a bound variable with an argument, in a β-reduction.

## The constraints

- A `rewrite` makes a `line` of `docs/math-parts.md` with the links of `docs/line-links.md`
  and the copies of `docs/part-copies.md`. The render, the presenter and the style sheet
  need no new code for the moves.
- The new line obeys the overlay contract of `docs/overlays.md`.
- A browser with no script shows each line complete at its step.
- The author gives the parentheses. The render adds none.

## An example

```elixir
math do
  reveal true

  line tex: ~S"\part{lam}{(\lambda f.}\,\part{body}{f\,(f\,x)}\part{close}{)}\,\part{arg}{g}"

  # Each f of the body becomes a copy of g, and the λ and the argument go.
  rewrite ~S"\to_\beta",
    replace: "f",
    within: "body",
    by: "arg",
    drop: ["lam", "close", "arg"]
end
```

The render makes the second line `g\,(g\,x)`, with the reason `f := g`. At the first step
of the rewrite, each `f` of the body and the argument get a color. At the next step, each
kept symbol, `(`, `x` and `)`, moves down to its place in the new line. At the third step,
a copy of `g` moves into each place of `f`.

A rule with variables matches a pattern:

```elixir
line tex: ~S"y = k\,(x + h)"

rewrite "=", rule: {~S"a\,(b + c)", ~S"a\,b + a\,c"}, vars: ~w(a b c)
```

The render makes the line `y = k\,x + k\,h`. Each variable of the right side is a copy of
the symbols that it matched, and each copy moves from the old line.

## The decisions

| Number | Question | Decision |
| --- | --- | --- |
| 1 | The entity | A `rewrite` entity of a math element makes the next line from the line before it, or from the line that `from` names. Its first argument is the relation, and the default is `=`. It takes the options `name` and `why` of a `line`. |
| 2 | The level | The check of a math element writes the LaTeX of the new line, with `\from{…}` around each kept part and each copy. Temml, the links of #474 and the copies of #473 then work as for a line that the author writes. |
| 3 | The occurrences | `replace` names a `\part` of the old line, or a symbol. A symbol is a letter, a digit or a command, such as `\alpha`, with an equal text. `within` limits the symbol to a part, as in `docs/each-occurrence.md`. |
| 4 | The new content | One of four options gives what goes into each place: `by` names a part of an earlier line, and a copy of it moves. `by_tex` gives new LaTeX, which fades in. `to` gives a template, and `rule` gives a pattern. The issue proposed `with`, and Spark makes a function for each option, so `with` conflicts with a special form of Elixir. |
| 5 | The parentheses | The author gives the parentheses in the source of `by`, such as `\part{arg}{(a + b)}`. The render adds none, so the result is predictable. |
| 6 | The removed parts | `drop` names the parts of the old line that the new line does not hold, such as the λ and the argument of a β-reduction. |
| 7 | The kept symbols | Each kept symbol of the old line moves to its place in the new line. A run of kept symbols inside one brace group becomes one part, `keep-n`, of the old line and one link of the new line. A command or a brace that holds an occurrence fades in. |
| 8 | A template | `to: ~S"\use{a}\,\use{b} + \use{a}\,\use{c}"` replaces the part of `replace`, or the whole line. Each `\use{name}` is a copy of the part `name` of the old line. |
| 9 | A pattern | `rule: {left, right}` and `vars` match the left side in the old line, or in the part of `replace`. A variable binds one atom: a symbol, a brace group or a group in parentheses. The match skips spaces such as `\,`. The first match from the left wins, and the render stops for no match. |
| 10 | The steps | A rewrite takes three steps of the counter of `reveal`: the occurrences and the source of `by` get a color, then each kept symbol moves, then each copy moves. The default reason is `replace := by`. Seven pull requests. `examples/animations/y_combinator.exs` writes each line after the first with `rewrite`, and the how-to guide gets an example of a rule with a GIF. |

## The design

- **The parser.** `Expresso.Element.Math.Latex` reads LaTeX into a tree of atoms: a symbol, a
  command with its brace groups, a brace group, a script, and a space. Each atom keeps its
  source, so the parser writes the same LaTeX back. It finds the extent of each `\part`.
- **The entity.** The DSL has a `rewrite` entity beside `line`. `Expresso.Element.Math.check/1`
  turns each rewrite into an `Expresso.Element.MathLine` in its place, before it writes the
  `aligned` formula. A rewrite needs a line before it.
- **The new line.** The check walks the tree of the old line. An occurrence becomes the new
  content, a dropped part goes away, and each run of kept atoms in one brace group gets a
  `\part{keep-n}{…}` in the old line and a `\from{keep-n}{…}` in the new line.
- **The new content.** `by` becomes `\from{name}{…}` with the LaTeX of the part. `by_tex`
  becomes its LaTeX. `to` becomes its template, and each `\use{name}` becomes
  `\from{name}{…}`. `rule` matches the left side, names each bound atom with a part of the
  old line, and writes the right side as a template.
- **The steps.** The rewrite gives the line three steps, as `steps: 2` of a line does with
  an `on` entity with `:next`. The part of each occurrence gets a color at the first step,
  the links of the kept symbols take the second step, and the links of the new content take
  the third step.

## The stack

Each pull request is based on the one before it.

1. This document.
2. The parser of LaTeX, `Expresso.Element.Math.Latex`.
3. The `rewrite` entity with `replace`, `within`, `by`, `by_tex` and `drop`.
4. The three steps and the default reason.
5. The template `to` with `\use`.
6. The pattern `rule` with `vars`.
7. `examples/animations/y_combinator.exs` with `rewrite`, and the guide with an example of
   a rule and its GIF.

## The progress

| Pull request | State |
| --- | --- |
| 1. This document | Done |
| 2. The parser of LaTeX | Done. `Expresso.Element.Math.Latex` reads LaTeX into atoms: a symbol, a command with its brace groups, a group, a script mark and a space. A number is one symbol. `write/1` returns the same LaTeX, and it puts a space between a command of letters and a letter. The name `Expresso.Element.Math.Tex` is the module that runs Temml, so the parser has a different name. |
| 3. The `rewrite` entity | Done. `Expresso.Element.Math.Rewrite.expand/1` runs first in `Expresso.Element.Math.check/1`, and it turns each rewrite into a line. A run of kept atoms gets the name `keep-k-n`, where `k` is the number of the new line. A base with a script is one unit, so a script stays on its base, and a plain script fades in. A new base of more than one atom goes into a group. `\text` and its kind hold no symbols. The options are `by` and `by_tex`, because `with` is a special form of Elixir. The spaces at the ends of the new line go away. |
| 4. The three steps and the default reason | Done. A line of a rewrite has `steps: 3`, and the check gives its part two `on` entities with `:next`, as for `steps: 2`. `Expresso.Element.Math.Links.place/1` reads and removes them: the occurrences, with the class `hit-k`, and the source of `by` get a color from the first step, the copies of `keep-k-n` move from the second step, and the other copies and the line take the third step. Without `why`, the reason is `replace := by` in LaTeX, in the new field `why_tex` of a line. A rewrite needs `reveal true`. |
| 5. The template `to` | Done. Each `\use{name}` of the template becomes `\from{name}{…}` with the body of the part in the nearest line. Without `replace`, the template is the whole new line, and the old line is its occurrence. A screenshot showed that Temml gives an operator in a part no space, so a kept run splits at each relation and each binary operator, and each operator gets its own part inside `\mathrel` or `\mathbin`. A sign with no operand before it stays in its run. The default reason holds no names, because a later link must not find a part in it. Temml drops a `\\class` that is the whole body of a `\\data`, so an occurrence that is the whole body of a line or a part gets an empty group after it. |
