# Cite your sources

This guide shows how to put a source under a slide with a footnote, and how to give the
audience a list of the sources of the talk. For each option, see
[The footnote element](../reference/footnote-element.md).

## Put a source under a slide

Write a `footnote` element in the slide. The renderer puts it at the bottom of the slide
with a number. Write the same number in the text, such as `<sup>1</sup>`, to point to the
footnote:

```elixir
defmodule Examples.Footnote do
  use Expresso

  slide "the claim" do
    heading "Small decks win"

    text_box do
      text_area do
        text "Talks with fewer than 20 slides got the best reviews.<sup>1</sup>"
      end
    end

    footnote "The reviews of a conference in 2024, from 312 talks."
  end
end

Examples.Footnote
```

![A claim with a mark 1, and footnote 1 at the bottom of the slide](https://raw.githubusercontent.com/rellen/expresso/media/footnote.png)

## Show a footnote at the step of its text

A footnote takes the overlay options. Give it the `at` option of the text that it
supports. The footnote keeps its number and its space, so the list does not move when it
shows:

```elixir
defmodule Examples.FootnoteAt do
  use Expresso

  slide "two claims" do
    heading "Two claims"

    list do
      reveal true
      item "BEAM processes are cheap.<sup>1</sup>"
      item "A crash stays in its process.<sup>2</sup>"
    end

    footnote "Approximately 2.6 kB of memory for each new process."
    footnote "The supervisor starts the process again.", at: [from: 2]
  end
end

Examples.FootnoteAt
```

![The second item and its footnote show together at step 2](https://raw.githubusercontent.com/rellen/expresso/media/footnote-at.gif)

## Give the audience a list of the sources

The handout view and paper end with a page of the sources of each slide. Press `p` to see
the handout view, or print the deck from the browser. The text of a footnote can contain
HTML, such as `<em>` for the title of a book:

```elixir
defmodule Examples.FootnoteSources do
  use Expresso

  slide "processes" do
    heading "Processes"

    text_box do
      text_area do
        text "A process is cheap.<sup>1</sup>"
      end
    end

    footnote "<em>Programming Erlang</em>, chapter 12."
  end

  slide "supervisors" do
    heading "Supervisors"

    text_box do
      text_area do
        text "A supervisor starts a process again.<sup>1</sup>"
      end
    end

    footnote "The documentation of <code>Supervisor</code>."
  end
end

Examples.FootnoteSources
```

![The two pages of the slides, then the page of the sources](https://raw.githubusercontent.com/rellen/expresso/media/footnote-sources.png)
