# Export a deck as PDF or as pictures

This guide shows how to write a PDF of a deck, and a PNG file of each slide, from the
command line. A build can then publish the slides of a talk with no browser window.

The guide uses this deck, in the file `deck.exs`:

```elixir
defmodule Examples.ExportDeck do
  use Expresso

  name "The release"
  slide_numbers true

  slide "plan" do
    heading "The plan"
    notes "Say the day of each step."

    list do
      reveal true
      item "Freeze the code on Monday"
      item "Test on Tuesday and Wednesday"
      item "Release on Thursday"
    end
  end

  slide "risks" do
    heading "The risks"

    list do
      item "A test that fails late"
      item "A dependency with a new version"
    end
  end
end

Examples.ExportDeck
```

![The slide "The plan" at its last step: a list of three items](https://raw.githubusercontent.com/rellen/expresso/media/export-deck.png)

## Install a browser

The export needs Chrome or Chromium, as `--check=layout` does. It needs no other tool.

1. Do the steps of
   [Install a browser for the layout check](check-a-deck.md#install-a-browser-for-the-layout-check).
2. If the export does not find the browser, give its path in `EXPRESSO_CHROMIUM`.

## Write a PDF of the slides

Give the option `--pdf` with the path of the file:

```sh
mix expresso deck.exs --pdf deck.pdf
```

The command writes one line:

```
Wrote deck.pdf: 2 pages.
```

The PDF has one page for each slide, and the page shows the slide as the present view
shows its last step, with the theme of the deck. The page has the size of a window of
1920 × 1080 pixels.

- To get a page for each step, add `--pdf-steps all`. The PDF of the example then has four
  pages.
- To get a different size, add `--size`, such as `--size 1280x720` or `--size 1024x768`
  for a screen of 4:3.

## Write a PDF for paper

Add `--pdf-pages handout`. The PDF then holds the handout view, as the print dialog of
the browser gives it: the notes under each page, the theme of paper and the steps of the
`handout` option.

```sh
mix expresso deck.exs --pdf handout.pdf --pdf-pages handout
```

- The paper is A4. Add `--pdf-paper letter` for letter paper.
- Each step of the example has a page, so the PDF has four pages. Write `handout :last`
  in the deck to get one page for each slide.
- `--pdf-steps all` gives a page to each step, as the key `a` does in the handout view.

## Write a picture of each slide

Give the option `--png` with a directory:

```sh
mix expresso deck.exs --png slides
```

The command makes the directory, and it writes `slides/slide-1.png` and
`slides/slide-2.png`. Each file shows the last step of its slide at 1920 × 1080 pixels.

- To get a file for each step, such as `slides/slide-1-step-2.png`, add
  `--png-steps all`.
- To get a different size, add `--size`, such as `--size 1280x720`.

One command can write the HTML, the PDF and the pictures:

```sh
mix expresso deck.exs deck.html --pdf deck.pdf --png slides
```

## Export a deck in a workflow

This job of GitHub Actions writes the PDF of a deck in a Mix project, and it keeps the
file. The runner of GitHub has Chrome on its `PATH`:

```yaml
jobs:
  slides:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: erlef/setup-beam@v1
        with:
          version-file: .tool-versions
          version-type: strict
      - run: mix deps.get
      - run: mix expresso deck.exs --pdf deck.pdf
      - uses: actions/upload-artifact@v7
        with:
          name: slides
          path: deck.pdf
```

The exit status of the export is 1 for an error, so the job fails when the export fails.

See [The export options](../reference/export-options.md) for each option and each error.
