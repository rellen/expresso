# The advance option and the loop option

The `advance` option gives each step a time. The present view goes to the next step when
that time ends. The `loop` option of the deck makes the first slide the slide after the
last one. Use them for a talk with a fixed time for each slide. Use them also for a deck that
runs on a screen with no presenter.

```elixir
defmodule MyDeck do
  use Expresso

  advance 20_000
  loop true

  slide "title" do
    advance false
    heading "Three facts about the BEAM"
  end

  slide "processes" do
    heading "Processes"
  end
end
```

`Expresso.Builder` takes the same options, such as `slide("title", advance: false)` and
`deck(slides, advance: 20_000, loop: true)`.

## The values of advance

| Where | Value | Effect |
| --- | --- | --- |
| The deck | `advance 20_000` | Each step of each slide has 20 seconds. The time is in milliseconds. |
| The deck | No option | A step has no time, and it waits for a key. This is the default. |
| A slide | `advance 10_000` | Each step of the slide has 10 seconds. It replaces the time of the deck. |
| A slide | `advance [12_000, 8_000]` | Step 1 of the slide has 12 seconds, and step 2 has 8 seconds. |
| A slide | `advance false` | The slide has no time, so it waits for a key. |
| A slide | No option | The slide has the time of the deck. |

The time is the time of one step. A slide with three steps and `advance 10_000` shows for
30 seconds.

A list gives the time of each step in sequence. A step after the end of the list takes
the last time of the list, and a time after the last step has no effect. The speaker view
makes such lines from a rehearsal. See
[Rehearse a talk and record the time of each slide](../how-to/rehearse-a-talk.md).

## The values of loop

| Value | Effect |
| --- | --- |
| `loop true` | The step after the last step of the talk is step 1 of the talk's first slide. The clock and the keys of the next step go to it. |
| No option, or `loop false` | The last step of the talk has no step after it. This is the default. |

The key of the previous step does not go from the first slide to the last slide. A
[hidden slide](hidden-option.md) is not a part of the talk, so the loop does not show it.

## The clock

The **clock of the steps** counts the time that the step that shows used. These rules
apply:

| Event | Effect on the clock |
| --- | --- |
| A different step shows, from the clock or from a key | The time of the new step starts from zero. |
| The key `a` | The clock stops, in the two windows. The step waits. A second `a` starts the clock, and the step continues its time. |
| A black screen or a white screen | The clock stops until the slide shows again. |
| The handout view of the present view | The clock stops until the present view shows again. |
| The overview, the menu and the list of keys | The clock continues. |
| A video or a sound of the slide plays | The step does not end before the end of the clip. A clip with `loop true` does not count. |
| The last step of a deck with no `loop true` | The step has no time. It waits for a key. |

The keys of the next step and of the previous step move as in each deck, also while the
clock is stopped.

## The speaker view

The speaker view shows the time left of the step under the timer:

| Text | Meaning |
| --- | --- |
| `Next step in 0:12` | The clock runs, and the step ends in 12 seconds. |
| `Clock stopped, 0:12 to the next step` | The key `a` or a black screen stopped the clock. The text has the color of the role `warning` after the key `a`. |
| No text | The step has no time. |

Only the present view goes to the next step. A speaker view with no present view shows
the time, and it does not move.

## The address

`?paused` in the address stops the clock at the load, as the key `a` does:

```
deck.html?paused
```

Press `a` to start the clock. The time of the step starts then.

`?rehearse` in the address is a rehearsal. The present view then has no clock, and the key
`a` does not start one. See [The time of each slide](presenter.md#the-time-of-each-slide).

## The tools

| Tool | With a time |
| --- | --- |
| `mix expresso <input> --check=layout` and `--check=a11y` | The check shows each step itself, so the page has no clock. |
| `mix expresso <input> --check=browser` | The check opens the document with `?paused`. |
| `mix expresso <input> --pdf` and `--png` | The export opens the document with `?paused`. A picture of a step shows that step. |
| The handout view and paper | They show each step, as for each deck. |

## The custom property

| Property | Effect |
| --- | --- |
| `--clock-stopped-color` | The color of the time left in the speaker view while the key `a` has the clock stopped. The default is the role `warning`. |

## The limits

- A deck with one step and `loop true` has no step to go to, so its step has no time.
- The speaker view does not know when the present view shows its handout view. Its time
  left then continues to count.

For the steps, see [Run a deck by time](../how-to/run-a-deck-by-time.md).
`docs/timed-advance.md` gives the reasons for the design.
