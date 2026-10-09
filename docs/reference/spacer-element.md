# The spacer element

The `spacer` element has no content. It takes the free space of its container, and it pushes
the elements after it to the end.

```elixir
slide "top and bottom" do
  text_box do
    text_area do
      text "This text is at the top."
    end
  end

  spacer()

  text_box do
    text_area do
      text "The spacer pushes this text to the bottom."
    end
  end
end
```

Write `spacer()` with the parentheses. Elixir reads a bare `spacer` as a variable.
`Expresso.Builder` has `spacer()` too.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| `class` | CSS class names | See [the class option](class-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## The layout

The theme gives the spacer `flex-grow: 1`. These are the results:

| The spacers | The result |
| --- | --- |
| One spacer between two elements | The first element goes to the start, and the second element goes to the end. |
| Two spacers around one element | The element goes to the middle. |
| A spacer in a column | The spacer pushes the elements of the column. See [the columns element](columns-element.md). |

A spacer at the end of a slide, a text box or a column has no visible effect.
