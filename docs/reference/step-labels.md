# Step labels

A step label is a short name for one step of a slide, such as "The restart". The speaker
view shows the label of the current step after the position, and the menu of `m` shows
the label of each step. See "The menu" in the README.

```elixir
slide "restart" do
  labels ["The tree", "The error"]

  list do
    reveal true
    item "The supervisor starts three workers"
    item "One worker stops with an error"
  end

  pause label: "The restart"

  text_box do
    at :next
    text_area do
      text "The supervisor starts it again"
    end
  end
end
```

## The two forms

| Form | Where | The step that it names |
| --- | --- | --- |
| `labels [...]` | An option of the slide | Each string names one step, from step 1. `nil` gives a step no label. |
| `pause label: "..."` | A `pause` in the slide | The step after the pause: the first step of an element after the pause with `:next`. |

The two forms can name different steps of one slide. In the example, `labels` names steps
1 and 2, and the pause names step 4. Step 3 has no label: the pause adds 1 to the counter
of the slide, so no element shows first at step 3. See [`pause`](overlay-options.md#pause).

A step with no label keeps the position alone, such as "Slide 4 of 13, step 3 of 4". A
step with a label gets it after a colon, such as "Slide 4 of 13, step 4 of 4: The restart".

`Expresso.Builder` takes the same options:
`Builder.slide("restart", labels: ["The tree"], elements: [...])` and
`Builder.pause(label: "The restart")`.

## The errors

The compiler gives an error for:

- a label of a step that the slide does not have, such as a fourth string in `labels` for
  a slide with three steps,
- a step with two labels, one from `labels` and one from a pause.

`Expresso.Builder.deck/2` raises a `Spark.Error.DslError` with the same message.

For the steps, see
[Name the steps of a slide](../how-to/animate-elements.md#name-the-steps-of-a-slide).
