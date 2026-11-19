# The export options

The options `--pdf`, `--png` and `--card` of `mix expresso` and of the binary write a PDF
of a deck, a PNG file of each slide, and the picture of the preview of a link. A headless
Chrome or Chromium writes the files.

```sh
mix expresso <input> [output] --pdf <file>
mix expresso <input> [output] --pdf <file> --pdf-pages handout --pdf-paper letter
mix expresso <input> [output] --png <directory> --png-steps all --size 1280x720
mix expresso <input> [output] --card <file> --card-slide 2
```

For the steps, see [Export a deck as PDF or as pictures](../how-to/export-a-deck.md). For
the design, see [The export](../export.md).

## The arguments

| Argument | Effect |
| --- | --- |
| `<input>` | The deck file, or `-` for the standard input. The export needs it. |
| `[output]` | The file for the HTML. Without it, the export writes no HTML. `-` is an error, because the export writes a line for each file to the standard output. |

## The options of the PDF

| Option | Value | Effect |
| --- | --- | --- |
| `--pdf` | The path of a file, such as `deck.pdf` | Write the PDF to that file. |
| `--pdf-pages` | `slides` or `handout` | The form of the pages. The default is `slides`. |
| `--pdf-steps` | `all` | A page for each step. |
| `--pdf-paper` | `a4` or `letter` | The paper of the form `handout`. The default is `a4`. |
| `--size` | A width and a height, such as `1280x720` | The size of a page of the form `slides`. The default is `1920x1080`. |

| | `--pdf-pages slides` | `--pdf-pages handout` |
| --- | --- | --- |
| The pages | The last step of each slide. | The steps of [the handout option](presenter.md#the-handout-view) of each slide. |
| With `--pdf-steps all` | Each step of each slide. | Each step of each slide, as the key `a` gives. |
| The size of a page | The size of `--size` in pixels, with no margin. The text has the size that it has in a window of that size. | The paper of `--pdf-paper`, landscape, with a margin of 1 cm. |
| The colors | The theme of the deck. | The theme of paper, which is the default theme. See [The theme option](theme-option.md). |
| The notes of the speaker | None. | Under each page, except with `print_notes false`. |
| The page of the sources | None. | After the last page, when a slide has a footnote. |
| A chart or a tree with frames | The frame of the step. | Each frame, as paper shows it. |

## The options of the PNG files

| Option | Value | Effect |
| --- | --- | --- |
| `--png` | The path of a directory, such as `slides` | Write the PNG files into that directory. The export makes the directory. |
| `--png-steps` | `all` | A file for each step. |
| `--size` | A width and a height, such as `1280x720` | The size of each picture in pixels. The default is `1920x1080`. |

| Steps | Name of a file |
| --- | --- |
| The last step of each slide | `slide-3.png` |
| Each step, with `--png-steps all` | `slide-3-step-2.png` |

The number of a slide is its number in the address of the deck, such as `#3.2`. Each
number has the digits of the largest number, so a deck with 12 slides gives
`slide-03.png`, and the names sort in the order of the deck. A picture shows the present
view with no progress bar. A file with the same name in the directory gets the new
picture, and each other file of the directory stays.

## The options of the card

| Option | Value | Effect |
| --- | --- | --- |
| `--card` | The path of a `.png` file, such as `card.png` | Write the picture of the preview of a link to that file: one PNG file of 1200 × 630 pixels. |
| `--card-slide` | The number of a slide, such as `2` | The slide of the card. The default is `1`. It needs `--card`. |

- The browser opens the slide in a window of 1200 × 630 pixels. The slide fills the
  window, and the text has the size for a window of that size. See
  [The size of a slide](slide-size.md).
- The card shows the last step of the slide, with no progress bar, as a PNG file of
  `--png` does.
- The number of a slide is its number in the address of the deck, as for the name of a PNG
  file. A hidden slide counts, and it can be the slide of the card.
- `--size` does not change the card.
- The export makes the card before it renders the document. The
  [card option](link-preview-options.md) of the deck can thus name the file of `--card`,
  and that file can be missing. The document then holds the new picture.

## These rules apply

- A hidden slide has no page and no file. The deck option `handout_hidden true` gives it
  its pages and its files. See [The hidden option](hidden-option.md).
- `--pdf`, `--png` and `--card` can go together, and with an `[output]` file.
- The export takes one `--size`. Each side is from 200 to 8000 pixels. `--size` needs
  `--pdf` or `--png`.
- A deck with a light and a dark variant of its theme gives the light variant.
- The export writes each file only after the browser made it, so an error leaves no part
  of a file.

## The output and the exit status

The export writes one line for each option to the standard output:

```
Wrote card.png: slide 1 at 1200 × 630.
Wrote deck.pdf: 12 pages.
Wrote 12 PNG files to slides.
```

The exit status is 0. For an error, the export writes the message to the standard error,
and the exit status is 1.

| Error | Cause |
| --- | --- |
| `--pdf, --png and --card need Chrome or Chromium. ...` | The export found no browser. Install one, or give its path in `EXPRESSO_CHROMIUM`. |
| `EXPRESSO_CHROMIUM gives <path>, and that file does not exist.` | The variable gives a wrong path. |
| `The browser <path> did not end in 120 s. ...` | The browser did not write the file. Give a different browser, such as the headless shell of Playwright. |
| `The browser <path> made a picture of 500 × 667, and not of 375 × 667. ...` | Chrome cannot make a window narrower than 500 pixels. Use the headless shell of Playwright, or a larger `--size`. |
| `--pdf-pages needs --pdf` | An option of the PDF with no `--pdf`. `--png-steps` needs `--png` in the same way. |
| `--pdf-paper needs --pdf-pages handout` | The pages of the slides have the size of `--size`, and no paper. |
| `--card-slide needs --card` | The command gives `--card-slide` with no `--card`. |
| `--card writes a PNG file, so give a path that ends with .png` | The path of `--card` has a different extension, such as `.jpg`. |
| `--card-slide 7 names no slide. The deck has 4 slides.` | The deck has fewer slides than the number. |
| `--size needs --check=layout, --check=a11y, --check=browser, --pdf or --png. ...` | The command gives `--size` with `--card` only. The card always has 1200 × 630 pixels. |
| `--pdf, --png and --card do not go with --watch or --check` | Run the check or the watch mode in a different command. |
| `--pdf and --png take one --size` | The command gives `--size` more than one time. |

## The browser

The export looks for the browser as `--check=layout` does: `EXPRESSO_CHROMIUM`, then the
browsers of Playwright, then Chrome and Chromium on the `PATH`, then the usual places on
macOS. See [The check option](check-option.md). The headless shell of Playwright starts
fast, and it gives each size.
