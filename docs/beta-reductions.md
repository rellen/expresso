# Each step of a β-reduction

This document gives the design for a `reduce` entity of a derivation. The entity makes the
next line by one β-reduction of the line before it, and it shows the reduction in four steps.
The design holds only the parts that are special to the λ-calculus: a parser of λ-terms, the
rules of scope and a preset of steps. The document also records the progress of the work.
It records ten decisions, and each is settled. Issue #475 holds the same plan.

## The problem

With the `rewrite` entity of `docs/line-rewrites.md`, an author can write a β-reduction:
name the binder, the body and the argument with `\part`, and rewrite the bound variable with
the argument. The author must still find the parts, name them, and select the bound
variables. `replace` with a symbol selects each occurrence of the symbol, also the variable
of an inner λ with the same name.

The λ-calculus has rules for each of these parts, so the render can find them.

## The constraints

- A `reduce` makes a `rewrite` of `docs/line-rewrites.md`. The links, the copies, the moves
  and the presenter script need no new code.
- The parser reads the LaTeX that a line already has, with its parts and its links. One
  source gives the layout and the parse.
- A reduction obeys the overlay contract of `docs/overlays.md`.

## An example

```elixir
math do
  reveal true

  line tex: ~S"(\lambda f.\,f\,(f\,x))\,g"

  reduce :leftmost
end
```

The render makes the line `g\,(g\,x)` with the relation `\to_\beta` and the reason `f := g`.
The reduction takes four steps:

1. The λ with its binder and the argument get their colors.
2. Each bound variable gets the color of the binder.
3. The rest of the body moves down from the old line.
4. A copy of the argument moves into the place of each bound variable, and the line shows.

## The decisions

| Number | Question | Decision |
| --- | --- | --- |
| 1 | The entity | A `reduce` entity of a math element makes the next line by one β-reduction of the line before it, or of the line that `from` names. The default relation is `\to_\beta`, and the default reason is `x := argument`. It takes `name` and `why` as a `rewrite` does. |
| 2 | The syntax | The parser reads the LaTeX of the line with `Expresso.Element.Math.Latex`. A `\part`, a `\from` and a `\class` around a term are transparent, and spaces have no meaning. |
| 3 | The terms | A term is a variable, an abstraction `\lambda x.` with a body, an application of two terms, or a term in parentheses. A body goes as far right as it can, and an application groups from the left. The render stops for LaTeX that is not a λ-term. |
| 4 | The redex | `reduce "r1"` names a `\part` of the old line that holds the redex. `reduce :leftmost` takes the leftmost outermost redex, the one of normal order. |
| 5 | The rules of scope | The bound variables of a redex are the free occurrences of its variable in its body. An inner λ with the same variable hides the occurrences in its own body. |
| 6 | Capture | When the argument has a free variable that a λ of the body binds around a bound variable, the substitution captures it. The render stops with an error that names the variable. |
| 7 | The parentheses | A copy of the argument keeps the parentheses of its source. An argument that is not one variable and that has no parentheses gets them in each place. |
| 8 | The steps | A reduction takes four steps: `:redex`, `:bound`, `:body` and `:argument`. The option `steps` takes a list of groups, and each group is one step, such as `[[:redex, :bound], :body, :argument]`. A `rewrite` takes the same option with its phases `:occurrences`, `:kept` and `:copies`. |
| 9 | The colors | Two new roles of the theme, `binder` and `argument`, each with a dimmed color, color the λ, its binder and the bound variables, and the argument. Each built-in theme meets the contrast minimums for them. |
| 10 | The stack and the examples | Seven pull requests. `examples/animations/y_combinator.exs` unfolds `Y` with a `rewrite`, makes each β-reduction with `reduce :leftmost`, and folds the last line with a `rewrite`. The definition of `Y` needs no names. The how-to guide gets an example of a reduction with a GIF. |

## The design

- **The parser.** `Expresso.Element.Math.Lambda` reads the atoms of a line into terms. Each
  term keeps the path of its atoms in the tree of the line, so the render can put a part
  around it. The parser returns an error that names the LaTeX that it cannot read.
- **Scope and capture.** A function of the module returns the bound variables of a redex and
  the free variables of a term. A capture stops the render.
- **The reduction.** The check of a math element turns each `reduce` into a `rewrite` before
  it expands the rewrites. It puts a `\part` around the λ with its binder, the closing
  parenthesis, the body and the argument, and a class around each bound variable, in the old
  line. The rewrite then replaces the bound variables with the argument and drops the λ, the
  parenthesis and the argument.
- **The steps.** The rewrite takes the phases of the reduction. `Expresso.Element.Math.Links`
  gives the colors of `:redex` and `:bound` to their parts at their steps, and the copies of
  the kept runs and of the argument take the steps of `:body` and `:argument`.
- **The colors.** `Expresso.Palette` gets the roles `binder` and `argument`, from the slots
  `base0E` and `base0C`. The theme writes `--binder`, `--argument` and their dimmed colors.

## The stack

Each pull request is based on the one before it.

1. This document.
2. The parser of λ-terms, `Expresso.Element.Math.Lambda`.
3. The rules of scope and the error for a capture.
4. The `reduce` entity with a named redex.
5. `reduce :leftmost`.
6. The four steps, the option `steps` and the roles of the theme.
7. `examples/animations/y_combinator.exs` with `reduce`, and the guide with an example of a
   reduction and its GIF.

## The progress

| Pull request | State |
| --- | --- |
| 1. This document | Done |
| 2. The parser of λ-terms | Done. `Expresso.Element.Math.Lambda.parse/1` reads the atoms of `Expresso.Element.Math.Latex` into a variable, an abstraction, an application or a term in parentheses, and each term keeps the indices of its first and last tokens. `tokens/1` returns each token with its atoms and its path in the tree. A variable with its scripts, such as `x_1`, is one token with that name. A property test makes sure that the parser reads each term that a generator writes. |
| 3. The rules of scope and the error for a capture | Done. `free/1` returns the free variables of a term, and `redex/1` returns the parts of a redex by their tokens: the head with the λ and the parenthesis before it, the closing parenthesis, the body, the argument and each bound variable. An inner λ with the same variable hides its body. A λ of the body around a bound variable that binds a free variable of the argument stops the reduction with an error. `leftmost/1` returns the redex of normal order. |
