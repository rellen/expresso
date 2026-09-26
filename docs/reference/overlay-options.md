# The overlay options

These options animate the elements of a slide. An overlay divides a slide into steps. The
first step is step 1. For the design, see [Overlays](../overlays.md).

## The forms of a step specification

`at` and `on` take the same forms.

| Term | Steps |
| --- | --- |
| `3` | Step 3 only. |
| `2..4` | Step 2 to step 4. |
| `[2, 5..7]` | Step 2, and step 5 to step 7. |
| `[from: 2]` | Step 2 and each step after it. |
| `:next` | The current value of the counter of the slide. |
| `[from: :next]` | The current value of the counter, and each step after it. |
| `[2, from: 5]` | Step 2, and step 5 and each step after it. |

Each slide has a counter that starts at 1. `:next` takes the current value of the counter,
and then it adds 1 to the counter. `pause()` also adds 1 to the counter.

## `at`

The steps that show the element. The element fades in when the slide moves to one of these
steps, and it fades out when the slide moves to a different step. An element without `at`
shows at each step. A child shows only at the steps of its parent.

![Elements that fade in at steps 2 and 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-at.gif)

## `effect`

The way in which an element shows and hides at the steps of its `at` option.

| Value | Effect |
| --- | --- |
| `:fade` | The element fades in and out. This is the default. |
| `:grow` | The element fades in from 80% of its size to its size. |
| `:fly_up` | The element fades in and moves up by 1rem to its place. |
| `:fly_down` | The element fades in and moves down by 1rem to its place. |
| `:fly_left` | The element fades in and moves left by 1rem to its place. |
| `:fly_right` | The element fades in and moves right by 1rem to its place. |
| `:wipe` | A clip opens the element from left to right. The element does not fade. |
| `:blur` | The element fades in from a blur of 0.2rem to sharp. |

An element, a slide and the deck take the option. An element uses the nearest value: its
own value, then the value of the nearest parent, then the slide, then the deck. A list
with `reveal true` and `effect :fly_up` therefore flies each item in. An item with
`effect :fade` in that list fades.

At the last step of the element, the same effect runs in the other direction. An element
with `:grow` then gets smaller, and an element with `:fly_up` moves down. An element
without an `at` option shows at each step, so its effect has no result.

![Five boxes, each with a different effect](https://raw.githubusercontent.com/rellen/expresso/media/overlay-effects.gif)

![The items of a list fly up one after the other, and the last item flies out after a step back](https://raw.githubusercontent.com/rellen/expresso/media/overlay-effect-list.gif)

## `on`

An entity in an element that changes the element at a set of steps. The first argument is a
step specification.

| Option | Effect |
| --- | --- |
| `state: :alert` | The theme draws an outline around the element. |
| `state: :dim` | The element shows at 40% of its opacity. |
| `set: [x: "-300px", y: "0px"]` | The element moves by that distance. |
| `set: [scale: 1.5]` | The element changes its size by that factor. |
| `set: [rotate: "-8deg"]` | The element turns by that angle. |
| `set: [opacity: 0.3]` | The element shows at that opacity, from 0 to 1. |
| `set: [color: "#c92a2a"]` | The text of the element changes to that color. |

An `on` entity can be in each element, in an item of a list, in a row of a table and in
a part of a diagram. In a diagram, `x` and `y` are in the units of the SVG file. A part
inside a `text` element of the file, such as a `tspan`, can fade, dim and change its
color, and it cannot move or get an outline.

The theme owns the custom properties that `set` writes. The compiler gives a warning for a
key that the theme does not use. The theme of this project uses `x`, `y`, `scale`,
`rotate`, `opacity` and `color`.

Two `on` entities can apply at the same step, and each writes its own keys. The element
then moves, changes its size and turns together. Code keeps the colors of its syntax, and
`color` changes only the text without a syntax color. A theme can change the level of
`dim` with the custom property `--dim-opacity`.

![The alert state at step 2](https://raw.githubusercontent.com/rellen/expresso/media/overlay-alert.gif)

![The move of a box at step 2](https://raw.githubusercontent.com/rellen/expresso/media/overlay-move.gif)

![A box that grows at step 2 and turns at step 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-scale.gif)

![Text that turns red at step 2, and a box that fades to 30% at step 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-color.gif)

![A table row with an outline at step 2, and a row that moves at step 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-row.gif)

![A diagram box that moves up with its arrow at step 2, and a new box and arrow at step 3](https://raw.githubusercontent.com/rellen/expresso/media/overlay-diagram.gif)

## `reveal`

| Element | Value | Effect |
| --- | --- | --- |
| `list` | `true` | Each item shows at its own step. |
| `table` | `true` | Each row shows at its own step. |
| `code` | a list of line numbers and ranges, such as `[1..3, 5..6]` | Each group of lines shows at its own step. A line that does not show keeps its space. |

![The items of a list, one at each step](https://raw.githubusercontent.com/rellen/expresso/media/overlay-list.gif)

![Two groups of lines of code](https://raw.githubusercontent.com/rellen/expresso/media/overlay-code.gif)

## `dim`

`dim true` on a `list`, a `table` or a `code` element gives each child the state `dim` from
the first step of a later child. The newest child then shows in full, and the earlier
children show at 40%. The option reads the steps of the children, so it works with
`reveal` and with an `at` option on each child. A child without steps, such as the header
of a table, does not dim.

![The earlier items of a list dim](https://raw.githubusercontent.com/rellen/expresso/media/overlay-dim.gif)

![The earlier groups of lines of code dim](https://raw.githubusercontent.com/rellen/expresso/media/overlay-dim-code.gif)

## `auto_reveal`

The slide option `auto_reveal true` shows each element of the slide at its own step, one
after the other.

## `pause`

`pause()` between two elements of a slide adds 1 to the counter of the slide. It shows no
element by itself. An element after it reads the new value with `:next`. Write the
parentheses, because Elixir reads a bare `pause` as a variable.

## `speed`

The time of each animation of an element: its effect, the changes of its `on` entities
and the state `dim`.

| Value | Time |
| --- | --- |
| `:fast` | 150 ms |
| `:normal` | 300 ms, the time of the theme without the option |
| `:slow` | 600 ms |
| a number, such as `1200` | That number of milliseconds |

![Four boxes that move with different speeds](https://raw.githubusercontent.com/rellen/expresso/media/overlay-speed.gif)

## `easing`

The change of the speed during each animation of an element.

| Value | Easing |
| --- | --- |
| `:ease_in_out` | A slow start and a slow end. This is the easing of the theme without the option. |
| `:ease_out` | A fast start and a slow end. |
| `:linear` | The same speed from the start to the end. |
| `:spring` | A small overshoot at the end, as a spring. |

![Four boxes that move with different easings](https://raw.githubusercontent.com/rellen/expresso/media/overlay-easing.gif)

## The rules of `speed` and `easing`

An element, a slide and the deck take both options. An element uses the nearest value, as
for `effect`: its own value, then the value of the nearest parent, then the slide, then
the deck. A child of an element also animates with the time and the easing of that
element.

The options do not change the transition between slides. The transition option has its
own time. A reader who asks for reduced motion gets no animation, and each change is
instant. The same is true on paper.
