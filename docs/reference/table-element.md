# The table element

The `table` element shows `row` elements in a grid. The first row can be the header of the
table, and the first cell of each row can be the header of its row. A caption can give the
name of the table.

```elixir
slide "the keys" do
  table do
    caption "The keys of the presenter"
    header true
    row_header true
    reveal true

    row ["Key", "Action"]
    row ["j", "The next step"]

    row ["k", "The step before"] do
      on 3, state: :alert
    end
  end
end
```

`Expresso.Builder` takes the same options, such as
`table(caption: "Keys", header: true, elements: [row(["Key", "Action"])])`.

## The options of the table

| Option | Value | Effect |
| --- | --- | --- |
| `caption` | A string | The name of the table. It shows above the table, and a screen reader reads it when it moves into the table. The caption is text, and not HTML. |
| `caption_hidden` | `true` or `false` | Hides the caption from the eye and not from a screen reader. The table needs the `caption` option. The default is `false`. |
| `header` | `true` or `false` | Makes the first row the header of the table. The default is `false`. |
| `row_header` | `true` or `false` | Makes the first cell of each row after the header the header of its row. The default is `false`. |
| `reveal` | `true` or `false` | Shows each row at its own step. The header shows with the table. The default is `false`. See [the overlay options](overlay-options.md#reveal). |
| `dim` | `true` or `false` | Dims each row when a later row shows. The header does not dim. The default is `false`. See [the overlay options](overlay-options.md#dim). |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

## The options of a row

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A list of strings | The text of each cell. A cell can contain HTML. |
| `class` | CSS class names | See [the class option](class-option.md). |
| `morph` | A string | A key of the morph. See [the morph option](morph-option.md). |

A table and a row each take the overlay options, such as `at`, `effect` and the `on`
entity. See [the overlay options](overlay-options.md).

## The headers for a screen reader

A screen reader reads the headers of a cell when it moves to that cell. Give the options
that name the cells:

- `header true` when the first row names the columns.
- `row_header true` when the first cell of each row names its row, such as the key in the
  example.
- `caption` for the name of the table. A screen reader reads the caption before the first
  cell.

Use `caption_hidden true` when a heading of the slide already shows the name of the table.
The caption then names the table for a screen reader only.

## The HTML

The document writes a `table` element with the class `table`. Each row is a `tr` element
with the class `row`.

- With `caption`, the first child of the table is a `caption` element with the class
  `table-caption`.
- With `caption_hidden true`, the caption also has the class `table-caption-hidden`. The
  style sheet hides it from the eye and not from a screen reader.
- With `header true`, the first row goes into a `thead` element. Each of its cells is a
  `th` element with `scope="col"`.
- Each other row goes into the `tbody` element with `td` cells.
- With `row_header true`, the first cell of each row in the `tbody` element is a `th`
  element with `scope="row"`.

A cell with no text names nothing, so it is a `td` element in each place. An empty top left
corner is an example: a `th` element with no text has no name for a screen reader, and
axe-core reports it.

The rows can have different numbers of cells. A row with fewer cells shows no cell in the
places that it does not fill.
