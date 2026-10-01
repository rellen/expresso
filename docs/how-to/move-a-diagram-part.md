# Move a part of a diagram to another part

This guide shows how to move a part of an SVG diagram to the place of another part, such
as a box that moves from one station of a flow to the next. For each value of the option,
see [The overlay options](../reference/overlay-options.md).

## Give the elements an id

1. Open the SVG file in a text editor or in a drawing program.
2. Give an `id` to the element that moves, such as `id="widget"`.
3. Give an `id` to each place that it moves to, such as `id="booth"` and `id="dryer"`.

An element with an `id` can be a shape, such as a `rect`, or a group `g` of shapes. A group
gives the center of its shapes.

## Move the part at each step

Write a `part` for the element that moves, and an `on` entity with `move_to` for each step:

```elixir
slide "the line" do
  diagram "line.svg" do
    part "widget" do
      on 2, move_to: "booth"
      on 3, move_to: "dryer"
      on [from: 4], move_to: "packer"
    end
  end
end
```

At step 1 the widget is at its place in the file. At step 2 its center is at the center of
the booth, and so on. A step back moves it back.

## Change more than the place

The `set` of the same `on` entity can change the color, the size or the opacity at the
same step:

```elixir
part "widget" do
  speed :slow
  on 2, move_to: "booth", set: [color: "#e23b3b"]
  on [from: 3], move_to: "dryer", set: [scale: 1.2]
end
```

The `set` cannot hold `x` or `y`, because `move_to` gives them. The `speed` and `easing`
options of the part give the time and the easing of the move.

## Put the part above a place, and not on it

`move_to` puts the two centers on the same point, so the part can cover the text of its
target. Add a small shape with no fill at the point where the part must stop, give it an
`id`, and move the part to it:

```xml
<rect id="above-booth" x="230" y="40" width="1" height="1" fill="none"/>
```

```elixir
on 2, move_to: "above-booth"
```
