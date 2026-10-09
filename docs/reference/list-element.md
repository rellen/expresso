# The list element

The `list` element shows a list of `item` elements, with a bullet or a number for each item.
An item can hold a nested list.

```elixir
slide "the points" do
  list do
    reveal true
    dim true

    item "The first point"

    item "The second point" do
      list do
        ordered true
        item "A nested item"
        item "Another nested item"
      end
    end

    item "The third point, with <b>HTML</b>"
  end
end
```

`Expresso.Builder` takes the same options, such as
`list(reveal: true, elements: [item("One"), item("Two")])`.

## The options of the list

| Option | Value | Effect |
| --- | --- | --- |
| `ordered` | `true` or `false` | Gives a number to each item. The default is `false`, which gives a bullet. |
| `reveal` | `true` or `false` | Shows each item at its own step. The default is `false`. See [the overlay options](overlay-options.md#reveal). |
| `dim` | `true` or `false` | Dims each item when a later item shows. The default is `false`. See [the overlay options](overlay-options.md#dim). |
| `class` | CSS class names | See [the class option](class-option.md). |

## The options of an item

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string | The text of the item. It can contain HTML. |
| `goto` | A slide and a step, such as `[slide: 5]` or `[slide: "summary"]` | Makes the element a link to that slide and step. See [the goto option](goto-option.md). |
| `class` | CSS class names | See [the class option](class-option.md). |

A list and an item each take the overlay options, such as `at`, `effect` and the `on`
entity. See [the overlay options](overlay-options.md).

## Nested lists

An item holds one `list` after its text, and an item of that list can hold a list too.

## The HTML

The document writes an `ol` element for an ordered list and a `ul` element for each other
list, with the class `list`. Each item is an `li` element with the class `item`. The text
of an item goes into one `div`, as the text of [a text area](text-area-element.md) does.
