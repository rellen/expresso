# Each step of a β-reduction

This document gives the design for a `reduce` entity of a derivation. The entity makes the
next line by one β-reduction of the line before it, and it shows the reduction in four steps.
The design holds only the parts that are special to the λ-calculus: a parser of λ-terms, the
rules of scope and a preset of steps. The code contains this design. The document records
ten decisions, and each is settled. Issue #475 holds the same plan. The last section, "The
result", tells what changed during the work.

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
| 10 | The stack and the examples | Six pull requests. `examples/animations/y_combinator.exs` unfolds `Y` with a `rewrite`, makes each β-reduction with `reduce :leftmost`, and folds the last line with a `rewrite`. The definition of `Y` needs no names. The how-to guide gets an example of a reduction with a GIF. |

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
4. The `reduce` entity with a named redex and with `:leftmost`.
5. The four steps, the option `steps` and the roles of the theme.
6. `examples/animations/y_combinator.exs` with `reduce`, and the guide with an example of a
   reduction and its GIF.

## The progress

| Pull request | State |
| --- | --- |
| 1. This document | Done |
| 2. The parser of λ-terms | Done. `Expresso.Element.Math.Lambda.parse/1` reads the atoms of `Expresso.Element.Math.Latex` into a variable, an abstraction, an application or a term in parentheses, and each term keeps the indices of its first and last tokens. `tokens/1` returns each token with its atoms and its path in the tree. A variable with its scripts, such as `x_1`, is one token with that name. A property test makes sure that the parser reads each term that a generator writes. |
| 3. The rules of scope and the error for a capture | Done. `free/1` returns the free variables of a term, and `redex/1` returns the parts of a redex by their tokens: the head with the λ and the parenthesis before it, the closing parenthesis, the body, the argument and each bound variable. An inner λ with the same variable hides its body. A λ of the body around a bound variable that binds a free variable of the argument stops the reduction with an error. `leftmost/1` returns the redex of normal order. |
| 4. The `reduce` entity | Done. `Expresso.Element.Math.Reduce.prepare/3` turns each `reduce` into a `rewrite`. It gives the old line the parts `lam-k`, `close-k`, `body-k`, `arg-k` and `bound-k`, and the rewrite replaces `bound-k` with a copy of `arg-k` and drops the rest. A redex with no bound variable becomes its body through a template. A part goes around the atoms of a range of tokens only when no other token is in them, so a redex that crosses a part or a link stops the render. `:leftmost` is in this pull request, because it is three lines, so the stack has six pull requests. A rewrite gets the internal fields `paren` and `why_tex`, and the new line trims the spaces at the ends of each group. |
| 5. The steps and the roles of the theme | Done. A rewrite and a reduction each give the new line a plan: the number of steps, the color of each part at the step of its phase, and the steps when the copies of the kept runs and the other copies move. `steps` takes the groups of the phases, and the render stops for groups that do not hold each phase once in its order. `Expresso.Palette` gets the roles `binder` from `base0E` and `argument` from `base0C`, so each theme writes `--binder`, `--argument` and their dimmed colors. Tango gives `base0C` and `base0E` the same blue, so the default theme takes the cyan of the Tango palette for `base0C`. This also changes `--code-support` of the default theme, and `docs/reference/dim-contrast-option.md` gives the new roles that do not dim at 4.5. A redex with no bound variable moves its body at `:body`. |
| 6. The example and the guide | Done. `examples/animations/y_combinator.exs` unfolds `Y` with a `rewrite`, makes two reductions with `reduce :leftmost`, and folds the last line with a rule. `examples/animations/math_reduce.exs` and its GIF show a reduction in the how-to guide, and `docs/how-to/show-the-steps-of-a-proof.md` uses `reduce`. |

## The result

The six pull requests of the stack contain the design. These parts are different from the
plan, or the plan did not tell them:

- **The stack.** `:leftmost` is three lines, so it went into the pull request of the entity,
  and the stack has six pull requests in the place of seven.
- **A link across two terms.** A kept run of a rewrite follows the atoms of a line, and not
  its terms, so one link can hold the end of one term and the start of the next. A
  reduction splits such a link, and the part of its source, in two, such as `keep-2-1` and
  `keep-2-1-2`. The Y combinator needs this for its second reduction.
- **A body that is a λ.** When a term comes after the redex, a body that is a λ keeps the
  parentheses of its λ, so `(\lambda f.\,\lambda x.\,f\,x)\,g\,y` becomes
  `(\lambda x.\,g\,x)\,y`.
- **The spaces of a dropped part.** A run of dropped parts and spaces becomes one space when
  the kept atoms on its two sides need one, and no space after `(` or before `)`.
- **Two names on one symbol.** Temml puts the attributes of a `\part` that is the whole body
  of a `\part` on one element. A part of a reduction thus gets an empty group after it, as
  an occurrence of a rewrite does. The parser of LaTeX gives a naming command two groups
  only, so the empty group stays an atom.
- **The default theme.** Tango gives `base0C` and `base0E` the same blue, so the binder and
  the argument had one color. The maintainer chose the cyan of the Tango palette for
  `base0C`. It also changes `--code-support` of the default theme.
- **The fold of the Y combinator.** The argument of `g` is two links, and a rule does not
  look through a link for a symbol. A link is one operand of a rule, so the rule `a\,a` with
  the variable `a` matches the term applied to itself.
- **The Y combinator example.** It takes 15 steps in the place of 13, because each reduction
  takes four steps. Its definition of `Y` has no names, and only `Y` of the first line has a
  name, for the copy of the fold.
