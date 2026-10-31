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
| The commands that Temml refuses | Temml refuses each command that writes an attribute or reads a file, such as `\style` and `\includegraphics`. It allows `\class` and `\data`, and `\part` and `\id` name a part. |
| The watch mode | The watch mode keeps the MathML of each formula from one render to the next, so a change of one slide runs Temml for the formulas that changed. |

Use the `~S` sigil for the LaTeX, so that Elixir does not change a `\`.

## The parts of a formula

A part is a sub-term of a formula with a name. Three commands of the LaTeX give a name:

| Command | The MathML gets | Use |
| --- | --- | --- |
| `\part{redex}{(\lambda f.\,f)\,g}` | `data-part="redex"` on the sub-term | A part of the formula. |
| `\id{redex}{(\lambda f.\,f)\,g}` | `data-part="redex"` on the sub-term, as `\part` gives | A part. The MathML gets no HTML `id`, so two formulas with the same name do not clash. |
| `\class{redex}{(\lambda f.\,f)\,g}` | `class="redex"` on the sub-term | A part, and a class for a rule of the `css` option. |

```elixir
slide "the redex" do
  math tex: ~S"\part{redex}{(\lambda \part{bind}{f}.\,f\,x)\,\part{arg}{g}}"
end
```

- A part can hold other parts, such as `bind` and `arg` in `redex` above.
- Two sub-terms can have the same name. They are then one part.
- A name starts with a letter, and it holds only letters, digits, `-` and `_`. The compiler
  refuses a different name.
- The MathML argument can give a part with the attribute `data-part` or `class`.

## The steps of a part

A `part` entity of a `math` element gives a part its steps. It takes the overlay options, as
a part of a diagram does: `at`, `effect` and the `on` entity with `state` and `set`.

```elixir
slide "the redex" do
  math do
    tex ~S"\part{redex}{(\lambda \part{bind}{f}.\,f\,x)\,\part{arg}{g}}"

    part "bind" do
      on [from: 2], set: [color: "var(--accent)"]
    end

    part "arg", at: [from: 3]

    part "redex" do
      on 4, state: :alert
    end
  end
end
```

At step 2 the binder `f` gets the accent color, at step 3 the argument `g` shows, and at
step 4 an outline goes around the whole redex.

A `math` element with a `do` block takes `tex` inside the block, as above. The form
`math tex: ... do` gives the option to the MathML argument, and the compiler refuses it.

| Option | Effect on a part |
| --- | --- |
| `at` | The part shows at these steps, and keeps its space at the other steps. |
| `effect` | The way in which the part shows, such as `:grow` or `:fly_up`. |
| `on ..., state: :dim` | The part dims. |
| `on ..., state: :alert` | An outline goes around the part. |
| `on ..., set: [color: ...]` | The part gets that color. |
| `on ..., set: [x: ..., y: ..., scale: ..., rotate: ..., opacity: ...]` | The part moves, changes its size, turns or fades. |
| `on ..., move_to: "name"` | The part moves, so its center is at the center of the part `name` of the same formula. |

- A part with the name of two sub-terms changes both.
- The render stops for a `move_to` with a name that the formula does not have, and for a
  part that moves to itself.
- The render stops for a `part` with a name that the formula does not have, and the message
  gives the names of the parts.

## Each occurrence of a symbol

A `part` entity with `each` names each occurrence of a symbol, such as each `x` of a
polynomial. One entity then colors, dims or moves each occurrence.

```elixir
slide "the polynomial" do
  math do
    tex ~S"\part{body}{x^2 + 2x} + \exp(x)"

    # Each x of the formula. exp is a different symbol.
    part "xs" do
      each "x"
      on 2, set: [color: "var(--accent)"]
    end

    # Each x of the part body.
    part "inner" do
      each "x"
      within "body"
      on 3, state: :alert
    end
  end
end
```

| Option | Effect |
| --- | --- |
| `each` | The symbol, such as `"x"`, `"2"` or `"+"`. An occurrence is a symbol of the formula with that text. |
| `within` | The name of the part that holds the occurrences. The default is the whole formula. |
| `bare` | With `true`, a symbol with an index is not an occurrence, so `each "x"` does not select the `x` of `x_1` or of `x^2`. The default is `false`. |

- A part with `each` and with the name of a part of the formula, such as `part "body"` with
  `each "x"`, puts its options on each occurrence inside that part, and not on the part.
- An occurrence is one symbol with the same text, so `each "x"` does not select the `x` of
  `\exp`.
- By default, the base of a symbol with an index, such as the `x` of `x_1`, is an
  occurrence. With `bare true`, the base of `_`, of `^` or of both is not an occurrence. A
  prime is an index, so `bare` also skips the `x` of `x'`. The `x` of `(x)^2` stays an
  occurrence, because the base of the index is the group.
- The index of a symbol is an occurrence of its own text, so `each "1"` selects the `1` of
  `x_1`.
- `each` knows no rules of scope. It also selects the variable of a binder, such as the `x`
  of `\lambda x`.
- The render gives an error for a `within` that the formula does not have, and for a symbol
  with no occurrence. The compiler gives an error for `within` or `bare` without `each`,
  and for `each` in a part of a diagram.

## Move a part to another part

`on 3, move_to: "arg"` in a `part` of a formula moves the part at step 3, so its center is at
the center of the part `arg`. The place of a part comes from the fonts of the browser, so the
presenter script measures the two parts when the slide shows. The script measures again when
the size of the window changes and when a font loads.

- A part with two or more elements, such as a line, moves as one. Its center is the center of
  the box that holds each of its elements.
- The `set` of the same `on` entity can hold other keys, such as `color` and `scale`, and it
  cannot hold `x` or `y`, because `move_to` gives them.
- Each place is the place of the part at rest, without the moves of the other steps.
- A browser with no script shows the part at its own place at each step.

The render writes the move as `--x: var(--to-x-arg)` and `--y: var(--to-y-arg)`, and the
script sets these two custom properties on the part. `assets/src/move.ts` gives the rules.

## Copy a part to other places

A `copy` entity in a `part` of a formula makes a copy of the part at a step. The copy moves
to the center of a different part, and the part stays at its place. A β-reduction uses
copies to put the argument in the place of each bound variable.

```elixir
slide "the substitution" do
  math do
    tex ~S"(\lambda \part{bind}{f}.\,\part{hole1}{f}\,\part{hole2}{f})\,\part{arg}{g}"

    part "arg" do
      on 2, copy_to: ["hole1", "hole2"]
    end
  end
end
```

The `copy` entity and `copy_to` take the same options as in a diagram. See
[Copy a part to other places](overlay-options.md#copy-a-part-to-other-places).

- The render writes each copy as its own `math` element after the formula, so the formula
  keeps its layout. The presenter script puts the copy on its source before the steps.
- A source in a script, such as an exponent, is smaller than a symbol of the formula. The
  copy gets the width of its source.
- A copy does not change its target. To hide a bound variable when the argument lands on
  it, give the variable its own `part` with `at` or `on`.
- A screen reader does not read a copy, because it repeats a part.
- A browser with no script does not show a copy.

### Copy to each occurrence of a symbol

A copy to a set of `each` makes one copy for each occurrence. A β-reduction can thus put
the argument in the place of each bound variable with one entry.

```elixir
slide "the substitution" do
  math do
    tex ~S"(\lambda f.\,\part{body}{f\,f})\,\part{arg}{g}"

    part "holes" do
      each "f"
      within "body"
    end

    part "arg" do
      on 2, copy_to: ["holes"]
    end
  end
end
```

- The occurrence `n` of a set has the class `set-n`, such as `holes-1` and `holes-2`.
- The copy to the occurrence `n` has the name of the copy, `-` and `n`, such as
  `arg@holes-1`.
- A copy of a set to a set pairs the occurrences in order, so the copy of the first `a`
  goes to the first `b`. The render gives an error when the two sets have a different
  number of occurrences.
- A copy of a set to a part that is not a set moves the occurrences as one.
- The render gives an error for a copy of a copy to a set. Give each copy a copy of the
  source.

## The lines of a derivation

A derivation has a line for each step, and the lines align on their relations, such as `=`
or `→β`. A formula takes its lines in two forms.

### Aligned LaTeX

`\begin{aligned}` aligns the rows of the `tex` option on `&`. Give each row a part, so it can
take steps:

```elixir
slide "the proof" do
  math tex: ~S"""
  \begin{aligned}
    & \part{l1}{(a + b)^2} \\
    \part{l2}{=} & \part{l2}{a^2 + 2ab + b^2}
  \end{aligned}
  """
end
```

A cell of a row cannot be inside a group of a different cell, so a part of a row names each
cell, as `l2` does above.

### The line entity

The `line` entity writes the aligned LaTeX for you. Its first argument is the relation in
LaTeX, the `tex` option is the term, and the `why` option is the reason in a column at the
right.

```elixir
slide "the proof" do
  math do
    reveal true
    line tex: ~S"(a + b)^2"
    line "=", tex: ~S"(a + b)(a + b)", why: "the definition of a square"
    line "=", tex: ~S"a^2 + 2ab + b^2", why: "multiply out"
  end
end
```

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | LaTeX, such as `"="` or `~S"\to_\beta"` | The relation of the line. The first line usually has none. |
| `tex` | LaTeX | The term of the line. |
| `why` | Plain text | The reason of the line. A character such as `&`, `%` or `{` shows as it is. |
| `name` | A name | The name of the part of the line. The default is `line1`, `line2` and so on. |

- Each line is a part with its name, so a `part` entity can give it steps, such as
  `part "line2" do on 3, state: :alert end`. Its options add to the line.
- The MathML of each cell of a line has the attribute `data-line` with the name of the
  line. A `\part` that is the whole term of a line thus keeps its own name.
- `reveal true` on the `math` element shows each line at its own step. The first line shows at
  the first step of the element. A `part` of the deck without an `at` option does not take a
  step.
- A `math` element takes line entities, the MathML argument or the `tex` option, and one
  only.

### Link a line to an earlier line

`\from{name}{…}` in the LaTeX of a line marks a sub-term that comes from the part `name` of
an earlier line. At the step of the line, a copy of that part moves from the earlier line
to the sub-term, and the part stays in its line.

```elixir
slide "the reduction" do
  math do
    reveal true

    line tex: ~S"(\lambda f.\,f\,(f\,x))\,\part{arg}{g}"

    line ~S"\to_\beta",
      tex: ~S"\from{arg}{g}\,(\from{arg}{g}\,x)",
      why: "f := g"
  end
end
```

- A link names a part of the nearest earlier line that has a part with that name.
- Each `\from` makes one copy, so two links with one name make two copies.
- The copy stays on the sub-term at each later step, and the presenter script hides the
  sub-term under it. A browser with no script shows the sub-term, so the line is complete.
- A line with a link needs steps: give the math element `reveal true`, or give the part of
  the line an `at` option.
- `steps: 2` on a `line` entity moves the copies of its links at its first step, and shows
  the other symbols of the line, its relation and its reason at the next step. It needs
  `reveal true`.
- A `\part` inside a `\from`, such as `\from{arg}{\part{hole}{g}}`, names the linked
  sub-term and its copy. A `part` entity with that name thus changes the copy that shows.
  A part that holds only some symbols of the sub-term changes the same symbols of the copy.
- A part around a linked sub-term, such as its line, gives the copy its `on` entities, so a
  copy dims with its line.
- A link with the name of a set of `each` takes one occurrence of the set: the first link
  with that name takes the first occurrence in the earlier line, the second link takes the
  second occurrence, and so on.
- The compiler gives an error for `\from` in a math element without `line` entities and in
  the first line. The render gives an error for a name that no earlier line has, and for
  more links to a set than occurrences of the set in the earlier line.

`docs/line-links.md` gives the design.

### Write the next line by a rewrite

A `rewrite` entity makes the next line from the line before it by a substitution, so you do
not write the new line. The render writes the new line with links, so each kept symbol of
the old line moves down, and a copy of the argument moves into each place.

```elixir
slide "the reduction" do
  math do
    reveal true

    line tex: ~S"\part{lam}{(\lambda f.}\,\part{body}{f\,(f\,x)}\part{close}{)}\,\part{arg}{g}"

    rewrite ~S"\to_\beta",
      replace: "f",
      within: "body",
      by: "arg",
      drop: ["lam", "close", "arg"],
      why: "f := g"
  end
end
```

The rewrite makes the line `g\,(g\,x)`, with the reason `f := g`. It takes three steps of
the counter of `reveal`, one for each phase:

| Step | Phase | What changes |
| --- | --- | --- |
| 1 | `:occurrences` | Each occurrence in the old line gets the color `--accent`, and the source of `by` gets the color `--success`. |
| 2 | `:kept` | Each run of kept symbols, such as `(` and `x)`, moves down from the old line to its place. |
| 3 | `:copies` | A copy of the source of `by` moves into the place of each occurrence, and the rest of the new line shows, with its relation and its reason. |

| Option | Effect |
| --- | --- |
| The first argument | The relation of the new line, such as `~S"\to_\beta"`. The default is `=`. |
| `replace` | The name of a part of the old line, or a symbol, such as `"f"`, `"2"` or `~S"\alpha"`. Each occurrence becomes the new content. A rewrite with `to` or `rule` can omit it. |
| `within` | With a symbol, the name of the part of the old line that holds the occurrences. The default is the whole line. |
| `by` | The name of a part of the old line or of an earlier line. A copy of it moves into the place of each occurrence. |
| `by_tex` | New LaTeX for the place of each occurrence, in place of `by`. It fades in. |
| `to` | A template in LaTeX for the part of `replace`, or for the whole line without `replace`. Each `\use{name}` in it is a copy of the part `name`, and the rest fades in. |
| `rule` | A left side and a right side in LaTeX, such as `{~S"a\,(b + c)", ~S"a\,b + a\,c"}`. The first match of the left side in the old line, or in the part of `replace`, becomes the right side. |
| `vars` | The variables of `rule`, such as `~w(a b c)`. |
| `drop` | The names of the parts of the old line that the new line does not hold. |
| `from` | The name of the line that the rewrite reads. The default is the line before it. |
| `why` | The reason of the new line, as plain text. The default is the replaced symbol or part, `:=` and the new content, in LaTeX. |
| `name` | The name of the part of the new line, as for a `line`. |
| `steps` | A list of groups of the phases, such as `[[:occurrences, :kept], :copies]`. Each group is one step, and the new line shows at the last step. The groups hold each phase once, in the order of the table above. The default is `[:occurrences, :kept, :copies]`. |

- A rewrite gives each run of kept symbols of the old line a part, such as `keep-2-1`, and
  the new line a link to it. A relation, such as `=`, and a binary operator, such as `+`,
  get a part of their own inside `\mathrel` or `\mathbin`, so they keep their spaces. A symbol of `\text` or of `\operatorname` is not an occurrence.
- A group or a command that holds an occurrence, such as `\frac`, fades in with the new
  line.
- A rewrite adds no parentheses. Put them in the source of `by`, such as
  `\part{arg}{(a + b)}`.
- A rewrite can read a line that a rewrite makes, so each line after the first can be a
  rewrite.
- A rewrite needs `reveal true`, because it takes a step for each group of its phases.
- Each occurrence in the old line gets the class `hit-k`, where `k` is the number of the new
  line, so a `part` entity with that name can change it.
- The compiler gives an error for a rewrite with no line before it, for a name that the
  lines do not have, for a rewrite with no occurrence, for a rewrite with more or less than
  one of `by`, `by_tex`, `to` and `rule`, for `by` or `by_tex` without `replace`, and for a rewrite
  without `reveal true`.

#### A template

`to` gives the new content as a template. Each `\use{name}` in it becomes a copy of the part
`name` of the nearest line before the rewrite, so one part can go to two places.

```elixir
slide "distribute" do
  math do
    reveal true

    line tex: ~S"\part{prod}{\part{a}{k}\,(\part{b}{x} + \part{c}{h})}"

    rewrite replace: "prod", to: ~S"\use{a}\,\use{b} + \use{a}\,\use{c}", why: "distribute"
  end
end
```

The rewrite makes the line `k\,x + k\,h`: a copy of `k` moves to two places, and `+` fades
in. Without `replace`, the template is the whole new line, and the whole old line gets the
color of step 1.

#### A rule with variables

`rule` applies an equation to the old line. The left side is a pattern, and each variable
of `vars` binds the operand that it matches. The right side is the new content, and each
variable in it is a copy of its operand.

```elixir
slide "a rule" do
  math do
    reveal true

    line tex: ~S"y = k\,(x + h)"

    rewrite rule: {~S"a\,(b + c)", ~S"a\,b + a\,c"}, vars: ~w(a b c), why: "distribute"
  end
end
```

The rewrite makes the line `y = k\,x + k\,h`, and you give the old line no names.

- A variable binds one operand: a symbol or a command with its scripts, a brace group, or
  a group in parentheses from `(` to its `)`. A variable before a script, as in `a^2`,
  binds the base only.
- The match skips spaces, such as `\,`, so `a\,b` matches `k (x + h)`.
- A variable that occurs two times in the left side, as in `a + a`, must bind equal LaTeX.
- A command or a brace group of the left side, such as `\frac{a}{b}`, matches its groups in
  full.
- The first match from the left wins. With `replace`, the match must be inside that part.
- A match does not cross a `\part` or a `\from` of the old line, but it looks inside them.
- The render gives an error for a rule that matches nothing, and for a variable of the
  right side that the left side does not have.

`docs/line-rewrites.md` gives the design.

### Reduce a λ-term

A `reduce` entity makes the next line by one β-reduction. The render reads the λ-term in the
LaTeX of the old line, finds the redex, its bound variables and its argument, and writes a
rewrite for them, so you give no names but the redex.

```elixir
slide "a reduction" do
  math do
    reveal true

    line tex: ~S"(\lambda f.\,f\,(f\,x))\,g"

    reduce :leftmost
  end
end
```

The reduction makes the line `g\,(g\,x)`, with the relation `\to_\beta` and the reason
`f := g`. It takes four steps of the counter of `reveal`, one for each phase:

| Step | Phase | What changes |
| --- | --- | --- |
| 1 | `:redex` | The λ with its variable gets the color `--binder`, and the argument gets the color `--argument`. |
| 2 | `:bound` | Each bound variable gets the color `--binder`. |
| 3 | `:body` | Each run of the rest of the body moves down from the old line to its place. |
| 4 | `:argument` | A copy of the argument moves into the place of each bound variable, and the new line shows. |

| Option | Effect |
| --- | --- |
| The first argument | The redex: `:leftmost` for the leftmost outermost redex, the redex of normal order, or the name of a `\part` of the old line that holds the redex. |
| `relation` | The relation of the new line. The default is `~S"\to_\beta"`. |
| `from` | The name of the line that the reduction reads. The default is the line before it. |
| `why` | The reason, as plain text. The default is the variable, `:=` and the argument, in LaTeX. |
| `name` | The name of the part of the new line. |
| `steps` | A list of groups of the phases, such as `[[:redex, :bound], :body, :argument]`. Each group is one step, and the new line shows at the last step. The groups hold each phase once, in the order of the table above. The default is `[:redex, :bound, :body, :argument]`. |

- A λ-term is a variable, `\lambda x.` with a body, an application, or a term in
  parentheses. A variable is a letter, a number or a command such as `\alpha`, with its
  scripts. A body goes as far right as it can, and an application groups from the left.
- The parser reads through a `\part`, a `\from`, a `\class` and a brace group, so a
  reduction can read a line that a rewrite or a reduction made.
- The bound variables are the free occurrences of the variable in the body. An inner λ with
  the same variable keeps its own variable.
- An argument of more than one variable, such as `a\,b`, gets parentheses in each place,
  unless it has its own.
- A redex with no bound variable, such as `(\lambda f.\,y)\,a`, becomes its body. Its
  body moves at the phase `:body`.
- A body that is a λ keeps the parentheses of its λ when a term comes after the redex, so
  `(\lambda f.\,\lambda x.\,f\,x)\,g\,y` becomes `(\lambda x.\,g\,x)\,y`.
- The render gives an error for a line that is not a λ-term, for a part with no redex, and
  for a capture: a λ of the body around a bound variable that binds a free variable of the
  argument. Give that λ a different variable.
- A reduction gives the old line the parts `lam-k`, `close-k`, `body-k`, `arg-k` and
  `bound-k`, where `k` is the number of the new line.
- A link of the old line that occurs once, such as a kept run of a rewrite, can hold the end
  of one term and the start of the next. A reduction then splits the link and its source in
  two, such as `keep-2-1` and `keep-2-1-2`. A redex that crosses a `\part`, or a link that
  occurs more than once, stops the render.
- A part of a reduction that is the whole body of a `\part`, such as `\part{g}{g}`, gets an
  empty group after it, `\part{g}{\part{arg-2}{g}{}}`. Temml then keeps the two names on
  two elements.

`docs/beta-reductions.md` gives the design.

## The math font

The deck option `math_font` gives the font of each `math` element. The document holds the
font as a data URI, so a formula looks the same on each computer and needs no network.

```elixir
defmodule MyTalk do
  use Expresso

  math_font :stix

  slide "the formula" do
    math tex: ~S"\sum_{i=1}^n i = \frac{n(n+1)}{2}"
  end
end
```

| Value | Font | Size in the document |
| --- | --- | --- |
| `:latin_modern` | Latin Modern Math, the font of LaTeX. This is the default. | Approximately 540 kilobytes |
| `:stix` | STIX Two Math, a font in the style of Times. | Approximately 750 kilobytes |
| `:libertinus` | Libertinus Math. | Approximately 460 kilobytes |
| `:noto` | Noto Sans Math, a font without serifs. | Approximately 470 kilobytes |
| `:system` | A math font of the computer that shows the deck. | Approximately 20 kilobytes |

- A document holds the chosen font only when the deck has a `math` element. A deck with no
  formula is not larger.
- The text of `\text{…}` in a formula takes the font of the slide, from the custom property
  `--font-text`. See [the css option](css-option.md).
- `:system` holds no math font. A computer without a math font shows a formula with a font
  for text, and some symbols do not align.
- The style sheet of Temml for each font comes with the font, so its rules for stretched
  accents and arrows fit the font.

## Show the steps of a proof

[Explain a formula step by step](../how-to/explain-a-formula-step-by-step.md) shows the parts
and the lines with example decks. To move a copy of each symbol of a formula in a long proof,
see [Show the steps of a proof](../how-to/show-the-steps-of-a-proof.md), which draws the
formula as a diagram.
