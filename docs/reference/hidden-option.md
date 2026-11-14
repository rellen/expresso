# The hidden option

The `hidden` option of a slide keeps the slide out of the talk. The keys of the next step
and of the previous step skip the slide, and the presenter can still go to it. Use it for a
backup slide, such as a slide of numbers for the questions after the talk.

```elixir
slide "the numbers" do
  hidden true
  heading "The numbers of each year"
end
```

`Expresso.Builder` takes the same option, such as `slide("the numbers", hidden: true)`.

## The values

| Value | Effect |
| --- | --- |
| No option, or `hidden false` | The slide is a slide of the talk. This is the default. |
| `hidden true` | The slide is a hidden slide. |

## The talk

The **talk** is the slides that are not hidden, in the sequence of the deck. A hidden slide
keeps its place in the deck, and it is not a part of the talk.

| Part of the presenter | With a hidden slide |
| --- | --- |
| `j`, `k`, the arrow keys, a click and a swipe | They skip the hidden slide. |
| The start of the deck, `Home` and `End` | They go to the first slide and to the last slide of the talk. |
| The slide numbers of `slide_numbers true` | They count only the slides of the talk, such as `3 / 12`. A hidden slide shows no number. |
| A typed number and `Enter` | They go to the slide of the talk with that number. A hidden slide has no number. |
| The progress bar | It counts only the steps of the talk. It does not move on a hidden slide. |
| The position in the speaker view | `Slide 4 of 13` counts only the slides of the talk. A hidden slide shows `Hidden slide after slide 4 of 13`. |
| The next step in the speaker view | It shows the step that `j` goes to. |
| The time left and the pace in the speaker view | They count only the steps of the talk. |

## How to go to a hidden slide

| Way | Steps |
| --- | --- |
| The overview | Press `o`, select the slide, and press `Enter`. A click on the slide does the same. |
| The menu | Press `m`, move the cursor to the slide or to one of its steps, and press `Enter`. |
| A link | Give an element [the goto option](goto-option.md) with the name of the slide, such as `goto: [slide: "the numbers"]`. |
| The address | Open the address of the slide, such as `deck.html#5.1`. The address uses the place of the slide in the deck. |

The overview and the menu show a hidden slide with a dashed outline and with a lower
opacity. The menu shows a dash in the place of its number.

On a hidden slide, `j` and `k` go through its steps. After its last step, `j` goes to the
next slide of the talk. Before its first step, `k` goes to the slide of the talk in front
of it. Two hidden slides in sequence are one gap in the talk, so `j` on the first does not
go to the second.

## The place and the number

A slide has two numbers:

| Number | What it counts | Where the deck uses it |
| --- | --- | --- |
| The place | Each slide of the deck. The first slide is 1. | The address, such as `#5.1`, and a link by number, such as `goto: [slide: 5]`. |
| The number in the talk | Only the slides of the talk. | The slide numbers, the typed number, the position in the speaker view and the menu. |

In a deck with no hidden slide, the two numbers are the same. A template reads the place
from `slide.metadata.slide_number` and the number in the talk from
`slide.metadata.talk_number`, which is `nil` for a hidden slide.

## The handout view and paper

The handout view and paper leave out each page of a hidden slide. The key `a`, which shows
each step, does not show them. The page of the sources leaves out the footnotes of a hidden
slide.

The deck option `handout_hidden true` puts each hidden slide into the handout view and onto
paper, in its place:

```elixir
defmodule MyDeck do
  use Expresso

  handout_hidden true
end
```

A hidden slide then follows its `handout` option, as each other slide does. The page of
the sources then gives its footnotes under the heading `Hidden slide:` and the name of the
slide.

## The custom property

| Property | Effect |
| --- | --- |
| `--hidden-slide-opacity` | The opacity of the content of a hidden slide in the overview and in the menu. The default is 0.45. |

## The limits

- A deck in which each slide is hidden has no talk. It starts at its first slide, and `j`
  and `k` go only through the steps of the slide that shows.
- The `toc` element makes an entry for each section. A section that starts with a hidden
  slide has an entry, and its link goes to the hidden slide.

For the steps, see [Keep backup slides for the questions](../how-to/keep-backup-slides.md).
`docs/hidden-slides.md` gives the reasons for the design.
