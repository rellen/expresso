# The goto option

The `goto` option makes an element a link to a slide and a step of the deck. A click on
the link in the present view goes to that step.

## Where you write it

| Element | What the link holds |
| --- | --- |
| `text_area` | The text of the text area. |
| `image` | The image. The `alt` text is the name of the link, so give the image an `alt` option. |
| `item` | The text of the item. A nested list stays outside the link. |

```elixir
slide "contents" do
  text_area(text: "The summary", goto: [slide: 5])

  list do
    item "The details" do
      goto slide: 3, step: 2
    end

    item "The end" do
      goto slide: "end"
    end
  end
end
```

`Expresso.Builder` takes the same option, such as
`text_area(text: "The summary", goto: [slide: 3, step: 2])` or
`text_area(text: "The end", goto: [slide: "end"])`.

## The values

| Value | Target |
| --- | --- |
| `[slide: 5]` | Step 1 of slide 5. |
| `[slide: 5, step: 2]` | Step 2 of slide 5. |
| `[slide: "end"]` | Step 1 of the slide with the name `"end"`. |
| `[slide: "end", step: 2]` | Step 2 of the slide with the name `"end"`. |

The slide is a positive integer or the name of a slide. The first slide is slide 1. The
name of a slide is the first argument of `slide`, such as `slide "end" do`. The step is a
positive integer.

Use a name for a link in a deck that changes. A new slide in front of the target changes
the number of the target, and a link by number then goes to the wrong slide with no error.
A link by name goes to the same slide.

The deck must have the slide and the step:

- A deck from the DSL does not compile with a link to a slide or a step that it does not
  have. The error names the slide of the link.
- A deck from the DSL does not compile with a link to a name that no slide has, or that
  two or more slides have. The error gives the number of each slide with the name.
- `Expresso.Builder.deck/2` raises a `Spark.Error.DslError` with the same message.

## What a click does

| Where | Effect |
| --- | --- |
| The present view | The presenter goes to the slide and the step of the link. The browser history gets no entry, and the address shows the new step. |
| A black screen or the list of keys | The click closes the black screen or the list, and it does nothing more. |
| The overview | The click goes to step 1 of the slide of the page, as a click on each other part of the page does. |
| The speaker view | The click goes to the next step or to the previous step, as a click on each other part of the page does. |
| The handout view | The browser follows the link. The address then shows the slide and the step of the link. |

A click with a modifier, such as `Ctrl`, and a click with a button other than the main
button go to the browser.

## The keyboard and a screen reader

The link is an HTML link with the address of its step, such as `#5.2`. `Tab` moves to the
link, and `Enter` goes to its step. A screen reader reads the link as a link, with the
text or the `alt` text of the element as its name.

The list of keys of the present view shows the row "Click or tap a link".

## Rules

- A link can only go to a slide and a step of the deck. Thus the handout view and the print
  show each step that a link can show.
- The text of a text area or of an item with the option must hold no link. HTML does not
  permit a link inside a link.
- The link has the color `--accent` of the theme, and the browser draws a line under its
  text. A deck can set `--goto-color`.
