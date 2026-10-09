# The quotation element

The `quotation` element shows a quotation and the name of its source.

```elixir
slide "a quotation" do
  quotation "Less is more." do
    by "Ludwig Mies van der Rohe"
  end
end
```

`Expresso.Builder` takes the same options, such as
`quotation("Less is more.", by: "Ludwig Mies van der Rohe")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string | The text of the quotation. It can contain HTML. |
| `by` | A string | The name of the source. The document writes it as text, so HTML in it shows as characters. |
| `class` | CSS class names | See [the class option](class-option.md). |

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

## The HTML

The document writes a `figure` element with the class `quotation`. The text goes into a
`blockquote` element, and the source goes into a `figcaption` element.

## The name

The entity is `quotation`, and not `quote`, because `quote` is a special form of Elixir.
