# Copies of a part

This document gives the design for a copy of a part: a step makes a copy of a part of a
diagram or of a formula, and the copy moves to a different place while the part stays. The
document also records the progress of the work. It records ten decisions, and each is
settled. Issue #473 holds the same plan.

## The problem

A β-reduction puts a copy of its argument in the place of each bound variable. The argument
stays in the line before, and one copy goes into each hole. `move_to` moves one part to one
place, and the part then leaves its first place. A deck cannot show a substitution with
`move_to` alone.

`examples/animations/y_combinator.exs` uses this workaround:

1. The SVG file holds one extra copy of the source for each place, on top of the source.
2. Each copy has `at [from: n]` and `on [from: n], move_to: "hole1"`.
3. The copies thus fade in at the source and move to their places at step `n`.

Each copy needs its own `part` and its own element in the file. A formula cannot use the
workaround, because the MathML of a formula cannot hold a hidden copy of a sub-term without
a change to the layout of the formula.

## The constraints

- The output stays one HTML file.
- A copy obeys the overlay contract of `docs/overlays.md`, so the steps, the identities, the
  handout and the layout check reach a copy with little new code.
- The render measures a diagram, as `Expresso.Element.Diagram.place/1` does for `move_to`.
  The presenter script measures a formula, as `assets/src/move.ts` does for `move_to`.
- A browser with no script shows each copy of a formula at its target, at the last step.

## An example

```elixir
diagram "reduction.svg" do
  part "arg" do
    on [from: 2], set: [color: "var(--success)"]

    copy "hole1", at: [from: 3]

    copy "hole2", at: [from: 3] do
      on [from: 4], state: :dim
    end
  end

  # The copy that lands on hole1 moves again at step 5.
  part "arg@hole1" do
    on [from: 5], move_to: "hole3"
  end
end
```

The short form gives the same two copies, with no options of their own:

```elixir
part "arg" do
  on 3, copy_to: ["hole1", "hole2"]
end
```

At step 3, a copy of `arg` fades in on `arg` and then moves to `hole1`, and a second copy
moves to `hole2`. The part `arg` stays at its place. Each copy keeps its place at each later
step, and it does not show before step 3.

## The decisions

| Number | Question | Decision |
| --- | --- | --- |
| 1 | The elements | A part of a `diagram` and a part of a `math` element take copies. |
| 2 | The forms | A `copy` entity inside a `part` takes the name of the target as its argument, and the options `at`, `effect` and `as`, and `on` entities. The `copy_to` option of an `on` entity takes a list of targets, and it gives one `copy` entity for each target. |
| 3 | The steps of a copy | A copy shows from the first step of its `at`. A `copy_to` copy shows from the first step of its `on` entity, and it keeps its place at each later step. A copy does not show before its first step. |
| 4 | The arrival | At its first step, a copy fades in at its source, and then it moves to its target. The move starts when the fade ends. At a step back, the copy goes back to its source and fades out. |
| 5 | The name of a copy | The name of a copy is the name of its part, `@` and the name of its target, such as `arg@hole1`. The `as` option gives a different name. Two copies with the same name stop the compile. |
| 6 | A copy of a copy | A `part` entity can name a copy. Its options and its entities go to that copy, so the copy can take `move_to`, `copy` and `copy_to` as each other part does. A copy of a copy fades in at the place of the first copy at its step. |
| 7 | The target | A copy does not change its target. To hide a bound variable when the argument lands on it, give the target its own `at` or `on` entity. |
| 8 | The place of a copy | A copy rests on its source, and it gets to its target by `move_to`. Thus a copy uses the measure of `move_to` with no new code: the render measures a diagram, and the presenter script measures a formula. |
| 9 | A copy in a formula | The render writes each copy of a formula as its own `math` element in the box of the formula, out of the flow, so the formula keeps its layout. The presenter script puts the copy on its source. |
| 10 | The stack and the examples | Seven pull requests. `examples/animations/y_combinator.exs` uses copies, and its SVG file holds no extra copy. A new example of a formula goes into the guide with a GIF. |

## The design

- **The entity.** `Expresso.Element.Copy` holds a copy: `target`, `as`, `at`, `effect` and
  `on`. A `part` of a diagram and a `part` of a formula hold `copy` entities. The check of
  the element expands each `copy_to` into `copy` entities.
- **A copy is a part.** The check of the element gives each copy its own
  `Expresso.Element.Part`, after the part of its source, with the name of the copy and the
  field `copy_of`, the name of the source. The part of the copy has the steps of its `at`,
  an `on` entity with `move_to` its target from its first step, and its own `on` entities
  after that one. The transformer then gives the copy an identity, its steps and its rules
  as for each other part. A `part` entity with the name of a copy adds its options to it.
- **A copy in a diagram.** `Expresso.Element.Diagram.place/1` makes each copy before it
  measures the moves. It copies the element of the source after the source, and it gives
  each element of the copy a new `id`: the name of the copy, `-` and the old `id`. The
  copy thus has the place of its source, and `move_to` measures from there.
- **A copy in a formula.** `Expresso.Element.Math.place/1` copies the MathML of the source
  into a new `math` element with the class `math-copy`, in the box of the formula. The style
  sheet puts the copy out of the flow. `assets/src/move.ts` puts the copy on its source
  before it measures, so `move_to` measures from there.
- **The fade and the move.** At the first step of a copy, the rule of the copy delays the
  transition of its transform by the time of its fade, so the copy fades in at its source
  and then moves.
- **A copy of a copy.** Before its first step, a copy of a copy gets the move of its first
  copy, so it fades in at the place of the first copy and moves from there.
- **The screen reader.** A copy repeats a term, so each copy has `aria-hidden="true"`. The
  list of a graph and the MathML of the formula give the term one time.
- **The handout.** The page of each step shows the copies of that step at their places.

## The stack

Each pull request is based on the one before it.

1. This document.
2. The `copy` entity and copies in a diagram.
3. The `copy_to` option.
4. Copies in a formula.
5. A copy of a copy.
6. `examples/animations/y_combinator.exs` with copies, and its SVG file with no extra copy.
7. The guide, a new example of a formula and its GIF.

## The progress

| Pull request | State |
| --- | --- |
| 1. This document | Done |
| 2. The `copy` entity and copies in a diagram | Done. `Expresso.Element.Copy.expand/1` gives each copy its own part in the check of the diagram. `Expresso.Element.Diagram.place/1` adds the move and the delay of each copy from its steps, and it copies the element of the source. The reveal rule of a step sets each delay of a transition to zero, so the theme gives a copy its own list of delays with a higher specificity. A `copy` entity with a `do` block takes `at` inside the block, as `math` takes `tex`. A part of a formula refuses a copy until pull request 4. |
| 3. The `copy_to` option | Done. `Expresso.Element.Copy.expand/1` gives each target of `copy_to` a `copy` entity from the first step of its `on` entity. A `:next` has no step number before the transformer runs, so `copy_to` refuses it, and a `copy` entity takes `at: :next`. An `on` entity with `copy_to` outside a part stops the compile. |
