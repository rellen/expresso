# The table element

The `table` element shows `row` elements in a grid. The first row can be the header.

```elixir
slide "the keys" do
  table do
    header true
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
`table(header: true, elements: [row(["Key", "Action"]), row(["j", "The next step"])])`.

## The options of the table

| Option | Value | Effect |
| --- | --- | --- |
| `header` | `true` or `false` | Makes the first row the header of the table. The default is `false`. |
| `reveal` | `true` or `false` | Shows each row at its own step. The header shows with the table. The default is `false`. See [the overlay options](overlay-options.md#reveal). |
| `dim` | `true` or `false` | Dims each row when a later row shows. The header does not dim. The default is `false`. See [the overlay options](overlay-options.md#dim). |
| `class` | CSS class names | See [the class option](class-option.md). |

## The options of a row

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A list of strings | The text of each cell. A cell can contain HTML. |
| `class` | CSS class names | See [the class option](class-option.md). |

A table and a row each take the overlay options, such as `at`, `effect` and the `on`
entity. See [the overlay options](overlay-options.md).

## The HTML

The document writes a `table` element with the class `table`. With `header true`, the first
row goes into a `thead` element with `th` cells. Each other row goes into the `tbody`
element with `td` cells. Each row is a `tr` element with the class `row`.

The rows can have different numbers of cells. A row with fewer cells shows no cell in the
places that it does not fill.
