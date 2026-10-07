# Move a part of a diagram to another part

This guide shows how to move a part of an SVG diagram to the place of another part, such
as a box that moves from one station of a flow to the next. For each value of the option,
see [The overlay options](../reference/overlay-options.md).

## Give the elements an id

1. Open the SVG file in a text editor or in a drawing program.
2. Give an `id` to the element that moves, such as `id="widget"`.
3. Give an `id` to each place that it moves to, such as `id="booth"` and `id="dryer"`.

An element with an `id` can be a shape, such as a `rect`, or a group `g` of shapes. A group
gives the center of its shapes. A group with a label below its shape therefore has its
center below the center of the shape. To stop the part on the shape, give the `id` to the
shape.

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

## The complete deck

This SVG file has three stations and a widget. Each station is a `rect` with an `id`, and
its label is a separate `text` element:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 170" width="400" height="170">
  <title>A paint line</title>
  <line x1="20" y1="80" x2="380" y2="80" stroke="currentColor" stroke-width="2" stroke-dasharray="6 4"/>
  <rect id="booth" x="30" y="50" width="90" height="60" rx="6" fill="none" stroke="#4a90d9" stroke-width="4"/>
  <text x="75" y="140" text-anchor="middle" font-size="18" fill="currentColor">Booth</text>
  <rect id="dryer" x="155" y="50" width="90" height="60" rx="6" fill="none" stroke="#d94a4a" stroke-width="4"/>
  <text x="200" y="140" text-anchor="middle" font-size="18" fill="currentColor">Dryer</text>
  <rect id="packer" x="280" y="50" width="90" height="60" rx="6" fill="none" stroke="#3aa55d" stroke-width="4"/>
  <text x="325" y="140" text-anchor="middle" font-size="18" fill="currentColor">Packer</text>
  <rect id="widget" x="5" y="10" width="30" height="30" rx="4" fill="#e8a33d"/>
</svg>
```

The widget goes to the booth at step 2, to the dryer at step 3, and to the packer at
step 4. At the packer it also grows:

```elixir
defmodule Examples.DiagramMoveTo do
  use Expresso

  slide "the line" do
    heading "The paint line"

    diagram "examples/animations/line.svg" do
      width "70%"

      part "widget" do
        on 2, move_to: "booth"
        on 3, move_to: "dryer"
        on [from: 4], move_to: "packer", set: [scale: 1.5]
      end
    end
  end
end

Examples.DiagramMoveTo
```

![The widget moves to the center of the booth, then of the dryer, then of the packer, where it grows](https://raw.githubusercontent.com/rellen/expresso/media/diagram-move-to.gif)
