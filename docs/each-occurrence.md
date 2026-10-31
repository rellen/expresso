# Each occurrence of a symbol

This document gives the design for a part that names each occurrence of a symbol inside a
formula or inside a part, such as each `f` in the body of a λ. One entry can then color,
dim, move or copy each occurrence. The same option selects each token with a text in a
`code` element. The document also records the progress of the work. It records ten
decisions, and each is settled. Issue #479 holds the same plan.

## The problem

A talk often shows one variable at each place where it occurs: the bound variables of a λ,
each `x` of a polynomial, or each use of a name in a proof. A part of a formula names one
sub-term, so the author must give a name to each occurrence with `\part`, and must change
the names when the formula changes.

`examples/animations/y_combinator.exs` gives each bound variable its own part, `f1`, `f2`
and `bound`. The `code` element has the same problem: its `highlight` selects lines, or a
range from one text to another, and not each token with a text.

## The constraints

- An occurrence is a symbol of the MathML of a formula, or a token of the highlighter of a
  code element. A text inside a different symbol, such as the `x` of `exp`, is not an
  occurrence.
- A set of occurrences obeys the overlay contract of `docs/overlays.md`, as each part does.
- `each` knows no rules of scope. Issue #475 adds the rules of the λ-calculus.

## An example

```elixir
math do
  tex ~S"\part{body}{x^2 + 2x + x_1}"

  # Each x of the formula.
  part "xs" do
    each "x"
    on 2, set: [color: "var(--accent)"]
  end

  # Each x of the part body, and not the x of x_1.
  part "bare" do
    each "x"
    within "body"
    bare true
    on 3, state: :alert
  end
end
```

The short form puts the options of a part on each occurrence inside it:

```elixir
part "body" do
  each "x"
  on 2, set: [color: "var(--accent)"]
end
```

In a code element, a group of `highlight` takes `each`:

```elixir
code src: "lib/counter.ex", lang: :elixir do
  highlight [[each: "count"], 12..14]
end
```

## The decisions

| Number | Question | Decision |
| --- | --- | --- |
| 1 | The forms | `part "name", within: "scope", each: "x"` makes a new part, a **set**, with each occurrence of `x` inside the part `scope`. Without `within`, a part with the name of a part of the formula is the short form: its options go to each occurrence inside it. The issue proposed `in`, and `in` is a reserved word of Elixir, so a `do` block cannot call it. |
| 2 | The scope | Without `within`, and with a name that the formula does not have, the scope is the whole formula. |
| 3 | An occurrence | An occurrence is a token element of the MathML, `mi`, `mn` or `mo`, with the text of `each`. The text must be equal, so `each: "x"` does not select `exp`. |
| 4 | A symbol with an index | By default, the base of `x_1` or of `x^2` is an occurrence of `x`. The option `bare: true` selects only an `x` with no index. |
| 5 | The rules of scope | `each` selects each symbol, also a binder and the variable of an inner λ. A deck limits the set with `within`. Issue #475 adds the rules of scope of the λ-calculus. |
| 6 | The options of a set | A set takes the options of a part: `at`, `effect`, `on`, `move_to`, `copy` and `copy_to`. Its occurrences move as one with `move_to`. |
| 7 | A set as a target | A copy to a set makes one copy for each occurrence, so `on 3, copy_to: ["bound"]` puts the argument in the place of each bound variable. |
| 8 | A set as a source | A copy of a set to a set with the same number of occurrences pairs them in order. `\from{set}{…}` takes the next occurrence of the set at each link with that name. The render stops for a different number. |
| 9 | The code element | A group of `highlight` takes `[each: "text"]`. The tokens with that text are in focus at the step of the group, and each other token dims. `reveal` refuses `each`, because a hidden token leaves a hole in its line. |
| 10 | The stack and the examples | Seven pull requests. `examples/animations/y_combinator.exs` colors the bound variables with `each` and gives them no part. The how-to guide gets an example of each `x` of a polynomial, with a GIF. |

## The design

- **The options.** The `part` entity takes `each`, `within` and `bare`. The check of a math
  element refuses `within` and `bare` without `each`, and the check of a diagram refuses
  `each`.
- **The occurrences.** At render, `Expresso.Element.Math` finds the scope: the elements with
  the name of `within`, the part of the short form, or the whole formula. It finds each token
  inside the scope with the text of `each`. It gives each occurrence the class of the set,
  so the occurrences are the elements of a part as for `\class`.
- **The short form.** The part of the short form keeps its name, and its overlay attributes
  go on its occurrences and not on its scope.
- **Copies.** A copy to a set expands into one copy for each occurrence, with the target
  `set-n`, the class of the occurrence `n`. A copy of a set to a set pairs `set-n` with
  `target-n`. The copies of `docs/part-copies.md` and the measure of `assets/src/move.ts`
  do the rest.
- **Links.** `Expresso.Element.Math.Links` gives the link number `k` with the name of a set
  the occurrence `k` of the set in its source line.
- **The code element.** `Expresso.Element.Code` finds each token of the highlighter with the
  text of the group. The style sheet dims each other token at the step of the group, and
  the tokens of the group get the bar of focus.

## The stack

Each pull request is based on the one before it.

1. This document.
2. `each`, `within` and the short form in a math element.
3. The option `bare`.
4. A set as a target and as a source of copies and links.
5. `each` in a group of `highlight` of a code element.
6. `examples/animations/y_combinator.exs` with `each`.
7. The guide, an example of a polynomial and its GIF.

## The progress

| Pull request | State |
| --- | --- |
| 1. This document | Done |
| 2. `each`, `within` and the short form | Done. `Expresso.Element.Math.Each.place/1` runs first in `Expresso.Element.Math.place/1`. It gives each occurrence the class of its set, and a part of the short form takes the name `each-name`. An entity with a `do` block takes the options inside the block, as `each "x"`, because Spark gives the keyword list to the arguments. |
