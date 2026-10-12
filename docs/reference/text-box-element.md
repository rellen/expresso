# The text box element

The `text_box` element holds other elements in one group. The group shows, hides and moves
as one element.

```elixir
slide "the plan" do
  text_box do
    at from: 2

    text_area do
      text "Three steps:"
    end

    list do
      item "Measure"
      item "Change"
      item "Measure again"
    end
  end
end
```

`Expresso.Builder` takes the same options, such as
`text_box(at: [from: 2], elements: [text_area(text: "Three steps:")])`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## The children

A text box can hold each of these elements:

- `text_area`, `image`, `list`, `table`, `quotation`, `spacer` and `code`;
- `math`, `diagram`, `embed`, `video` and `audio`;
- `qr_code`, `chart`, `stat` and `icon`;
- `columns`, `callout` and `toc`.

A text box cannot hold a text box. See [The places of the elements](placement.md).

Use [the columns element](columns-element.md) to put groups side by side.

## The layout

The document writes a `div` with the class `text-box`. The theme puts the children in a
column, one under the other, in the center of the box. The text box takes the free space of
its parent. A `spacer` in the text box takes the free space of the box, and it pushes the
children after it to the end of the box.

An `at` option or an `on` entity on the text box applies to each child together. A child
can also have its own `at` option, and it then shows only at the steps of the two options.
