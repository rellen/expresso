# Make a deck accessible

This guide shows how to make a deck that a screen reader can read and that a keyboard can
present. The document gives the structure itself. Your deck gives the names and the texts.
For each part of the document, see [The accessibility of a deck](../reference/accessibility.md).

## Give each slide a heading

A screen reader names each slide with its number and its heading, such as "Slide 2 of 3: A
restart". The live region reads that name at each move to the slide. Without a heading, the
name of the slide is its `slide` name, such as "restart". The menu shows the same names.

```elixir
defmodule Examples.Accessible do
  use Expresso

  name "Supervisors"

  slide "start" do
    heading "Supervisors"
    labels ["The question"]
    text_area(text: "What happens when a process crashes?")
  end

  slide "restart" do
    heading "A restart"
    labels ["The crash", "The restart"]

    list do
      reveal true
      item "The process crashes"
      item "The supervisor starts it again"
    end
  end

  slide "result" do
    heading "The result"

    stat 99.9 do
      suffix "%"
      label "of the time, the service answers"
    end
  end
end

Examples.Accessible
```

![The deck moves to the second slide, then the menu opens and its cursor moves to the third slide](https://raw.githubusercontent.com/rellen/expresso/media/accessible.gif)

## Name the steps

The `labels` option of a slide names its steps. The menu shows each name, and a screen
reader reads it after the number of the step, such as "Step 1 The crash". A step without a
name is only "Step 2". See [Step labels](../reference/step-labels.md).

## Give each picture a text

A screen reader cannot see a picture, so give each one a text:

| Element | Option | Example |
| --- | --- | --- |
| `image` | `alt` | `alt "A supervisor with three workers"` |
| `chart` | `title` | `title "Orders for each month"` |
| `stat` | `label` | `label "of the time, the service answers"` |
| `icon` | `label` | `label "Expresso"` |
| `qr_code` | `title` | `title "The address of the slides"` |
| `video`, `audio`, `embed` | `title` | `title "The demo of the restart"` |

An image without `alt` is decorative, and a screen reader does not read it. Leave out `alt`
only for an image that gives no information.

## Make sure of the result

1. Open the deck in a browser with a screen reader, such as VoiceOver on macOS or NVDA on
   Windows.
2. Press `j`. The screen reader reads the name of the next slide, or the next step.
3. Press `m`. The screen reader reads the name of the current step. Press `j` and `k` to
   move the cursor, and listen for each name.
4. Press `p` for the handout view. Each page has the name of its slide and its step.

To find a missing text, run a checker such as [axe DevTools](https://www.deque.com/axe/)
in the browser. A violation names the element and the rule.
