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

## `on`

An entity in an element that changes the element at a set of steps. The first argument is a
step specification.

| Option | Effect |
| --- | --- |
| `state: :alert` | The theme draws an outline around the element. |
| `set: [x: "-300px", y: "0px"]` | The element moves by that distance. |

The theme owns the custom properties that `set` writes. The compiler gives a warning for a
key that the theme does not use. The theme of this project uses `x` and `y`.

![The alert state at step 2](https://raw.githubusercontent.com/rellen/expresso/media/overlay-alert.gif)

![The move of a box at step 2](https://raw.githubusercontent.com/rellen/expresso/media/overlay-move.gif)

## `reveal`

| Element | Value | Effect |
| --- | --- | --- |
| `list` | `true` | Each item shows at its own step. |
| `table` | `true` | Each row shows at its own step. |
| `code` | a list of line numbers and ranges, such as `[1..3, 5..6]` | Each group of lines shows at its own step. A line that does not show keeps its space. |

![The items of a list, one at each step](https://raw.githubusercontent.com/rellen/expresso/media/overlay-list.gif)

![Two groups of lines of code](https://raw.githubusercontent.com/rellen/expresso/media/overlay-code.gif)

## `auto_reveal`

The slide option `auto_reveal true` shows each element of the slide at its own step, one
after the other.

## `pause`

`pause()` between two elements of a slide adds 1 to the counter of the slide. It shows no
element by itself. An element after it reads the new value with `:next`. Write the
parentheses, because Elixir reads a bare `pause` as a variable.

## Timing

Each animation of an overlay lasts `--dur`, 300 ms in the theme of this project, with the
easing `--ease`. A reader who asks for reduced motion gets no animation, and each change is
instant.
