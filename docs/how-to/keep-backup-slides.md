# Keep backup slides for the questions

This guide shows how to keep a slide in a deck that the talk does not show, and how to go
to it when a question needs it.

## Hide a slide

Write `hidden true` in the slide:

```elixir
defmodule Examples.BackupSlides do
  use Expresso

  name "Backup slides"
  slide_numbers true

  slide "title" do
    heading "The cost of a cache"
  end

  slide "result" do
    heading "The cache halves the cost"

    text_box do
      text_area(text: "See the numbers", goto: [slide: "numbers"])
    end
  end

  slide "numbers" do
    hidden true
    heading "The numbers of each year"
  end

  slide "end" do
    heading "Questions?"
  end
end

Examples.BackupSlides
```

![The talk goes from the result to the last slide. The overview shows the hidden slide with a dashed outline, and Enter goes to it.](https://raw.githubusercontent.com/rellen/expresso/media/backup-slides.gif)

`j` on the slide "result" now goes to the slide "end". The slide numbers count three
slides, so "end" shows `3 / 3`.

You can put a hidden slide anywhere in the deck. A good place is after the slide that it
supports, because the overview then shows the two slides together.

## Go to a hidden slide during the talk

Use one of these ways:

1. Press `o` for the overview. The hidden slide has a dashed outline. Select it with the
   arrow keys, and press `Enter`.
2. Press `m` for the menu. Move the cursor to the hidden slide with `j` and `k`, and press
   `Enter`.
3. Click a link to the slide. The example above gives the text "See the numbers" a link
   with `goto: [slide: "numbers"]`.

Give a link the name of the slide, and not a number. A link by number uses the place of the
slide in the deck, and that place changes when you add a slide in front of it.

## Go back to the talk

On a hidden slide, press `j`. After the last step of the hidden slide, `j` goes to the next
slide of the talk. `k` goes to the slide of the talk in front of the hidden slide.

To go back to a different slide, type its number and press `Enter`. The number is the
number that the slide shows.

## Print the backup slides

The handout view and paper leave out each hidden slide. To print them, write
`handout_hidden true` in the deck:

```elixir
handout_hidden true
```

Each hidden slide then prints in its place, with the pages of its `handout` option.

## Make sure of the result

1. Open the deck, and press `j` to the end. Make sure that no hidden slide shows.
2. Press `o`, and make sure that each hidden slide has a dashed outline.
3. Press `p`, and make sure that the handout view shows only the slides that you want on
   paper.

See [the hidden option](../reference/hidden-option.md) for each rule of a hidden slide.
