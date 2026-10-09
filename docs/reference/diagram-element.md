# The diagram element

The `diagram` element shows an SVG file as a part of the document. Each `part` names an
element of the file, and that element can show, hide, move or change at steps.

```elixir
slide "the flow" do
  diagram "flow.svg" do
    width "60%"

    part "arrow", at: [from: 2]

    part "output" do
      at from: 3
      on 4, state: :alert
    end
  end
end
```

`Expresso.Builder` takes the same options, such as
`diagram("flow.svg", width: "60%", elements: [part("arrow", at: [from: 2])])`.

## The options of the diagram

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | The path of an `.svg` file | The diagram. A path is relative to [the root option](root-option.md) of the deck, or to the working directory of the command. |
| `width` | A CSS width, such as `"900px"` or `"60%"` | The width of the diagram. A percentage is a part of the width of the slide. The default is the width that the file gives. |
| `class` | CSS class names | See [the class option](class-option.md). |

## The options of a part

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | A string | The `id` of an element of the SVG file. |

A diagram and a part each take the overlay options, such as `at`, `effect` and the `on`
entity. The `on` entity of a part also takes `move_to`. See
[the overlay options](overlay-options.md#on).

## The errors

The render gives an error for these:

- a file that it cannot read;
- a part with an `id` that the file does not have;
- a `move_to` with an `id` that the file does not have, or with an element that has no shape.

## The theme and the SVG file

The document holds the SVG as elements, and not as a picture. The rules of the theme and
of [the css option](css-option.md) thus reach the parts of the diagram.

Each view gets its own copy of the file, with its own `id` values. A gradient or a marker
thus works in each view. An `id` in the document is therefore not the same as the `id` in
the file. Write a rule of the css option with a class of the file, and not with an `id`.

## A part that moves

A part with an `on` entity, or with an effect that moves it, goes into a `g` element with
the class `diagram-part`. The theme moves the `g` element, so the part keeps its own
`transform` attribute. A distance in `set: [x: ..., y: ...]` is in the units of the file.

A part inside a `text` element of the file, such as a `tspan`, can fade, dim and change
its color. It cannot move or get an outline.

## The watch mode

The watch mode renders the deck again after a change to the SVG file.
