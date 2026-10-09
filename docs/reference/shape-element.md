# The shape element

The `shape` element draws a rectangle, an ellipse, a line or an arrow over a slide. Use it
to point at a part of a slide, such as a line of code or a row of a table.

```elixir
slide "the result" do
  code "elixir" do
    text "Enum.map(orders, & &1.price)"
  end

  shape :ellipse, x: "30%", y: "42%", width: "40%", height: "16%", at: [from: 2]
  shape :arrow, from: ["80%", "20%"], to: ["70%", "45%"], at: [from: 2]
end
```

`Expresso.Builder` takes the same options, such as
`shape(:arrow, from: ["80%", "20%"], to: ["70%", "45%"])`.

## The options

| Option | Kinds | Value | Effect |
| --- | --- | --- | --- |
| The first argument | Each kind | `:rect`, `:ellipse`, `:line` or `:arrow` | The kind of the shape. |
| `x`, `y` | `:rect`, `:ellipse` | A CSS length, such as `"10%"` | The left edge and the top edge. |
| `width`, `height` | `:rect`, `:ellipse` | A CSS length, such as `"30%"` | The size. |
| `text` | `:rect`, `:ellipse` | A string | A short text in the center of the shape. |
| `fill` | `:rect`, `:ellipse` | `true` or `false` | Fill the shape with a light tint of its color. The default is `false`. |
| `from`, `to` | `:line`, `:arrow` | A list of two CSS lengths, such as `["10%", "50%"]` | The start and the end. The head of an arrow is at `to`. |
| `class` | Each kind | CSS class names | See [the class option](class-option.md). |

A rectangle and an ellipse need `x`, `y`, `width` and `height`. A line and an arrow need
`from` and `to`. The compiler gives an error for a missing option and for an option of the
other kinds.

The element also takes the overlay options, such as `at`, `effect` and the `on` entity. See
[the overlay options](overlay-options.md).

Write the options in the block when the shape also has a block, because the DSL does not
take options and a block in the same call:

```elixir
slide "a note" do
  shape :rect do
    x "60%"
    y "15%"
    width "30%"
    height "12%"
    text "One pass for each order"
    fill true
  end
end
```

## The place

A percentage is a part of the slide: `x` and the first length of a point are parts of the
width, and `y` and the second length are parts of the height. The point `["0%", "0%"]` is
the top left corner of the slide, and `["100%", "100%"]` is the bottom right corner. The
place does not depend on the other elements of the slide.

A shape shows nothing in the place where you write it. The renderer puts the shapes of a
slide into one layer over the whole slide, in the order of the deck. A shape thus covers
the content under it. The layer takes no click, so a click on a shape goes to the slide.

## The color and the line

| Custom property | Default | Effect |
| --- | --- | --- |
| `--shape-color` | `--accent` of the theme | The color of the line, of the head of an arrow, of the text and of the fill. |
| `--shape-width` | `0.15rem` | The width of the line. |

`on 3, set: [color: "var(--danger)"]` changes the color of a shape at a step, and the state
`dim` dims it, as for a text. `set: [x: "10vh"]` and `set: [y: "10vh"]` move it. Use `vh`
or `vw` for a move, so the move keeps its size in each window.
