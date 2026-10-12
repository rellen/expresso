# The columns element

The `columns` element puts its `column` elements side by side. A column holds elements, as a
text box does.

```elixir
slide "two sides" do
  columns do
    column do
      width "40%"

      list do
        item "A column of 40 percent"
        item "with a list"
      end
    end

    column do
      at from: 2

      text_area do
        text "A column that takes the rest, and shows at step 2."
      end
    end
  end
end
```

`Expresso.Builder` takes the same options, such as
`columns(elements: [column(width: "40%", elements: [...]), column(elements: [...])])`.

## The options of the columns

| Option | Value | Effect |
| --- | --- | --- |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

## The options of a column

| Option | Value | Effect |
| --- | --- | --- |
| `width` | A CSS width, such as `"30%"` or `"400px"` | The width of the column. The default is an equal part of the free space. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

The columns element and a column each take the overlay options, such as `at`, `effect`
and the `on` entity. See [the overlay options](overlay-options.md).

## The width of a column

| Columns | The result |
| --- | --- |
| No column has a `width` | Each column takes an equal part. |
| Some columns have a `width` | Those columns take their width, and the other columns share the rest. |
| Each column has a `width` | Each column takes its width. |

The document writes the custom properties `--column-width` and `--column-grow` on each
column with a `width` option, and the theme reads them. A column without the option gets
the defaults of the theme: it grows, and its base width is 0%.

## The children

A column can hold each element that [a text box](text-box-element.md) holds, except a
`columns` element. A column cannot hold a text box. See
[The places of the elements](placement.md).

A slide or a text box can hold a `columns` element.
