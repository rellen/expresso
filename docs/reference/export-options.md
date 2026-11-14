# The export options

The options `--pdf` and `--png` of `mix expresso` and of the binary write a PDF of a
deck, and a PNG file of each slide. A headless Chrome or Chromium writes the files.

```sh
mix expresso <input> [output] --pdf <file>
mix expresso <input> [output] --pdf <file> --pdf-pages handout --pdf-paper letter
mix expresso <input> [output] --png <directory> --png-steps all --size 1280x720
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

## These rules apply

- A hidden slide has no page and no file. The deck option `handout_hidden true` gives it
  its pages and its files. See [The hidden option](hidden-option.md).
- `--pdf` and `--png` can go together, and with an `[output]` file.
- The export takes one `--size`. Each side is from 200 to 8000 pixels.
- A deck with a light and a dark variant of its theme gives the light variant.
- The export writes each file only after the browser made it, so an error leaves no part
  of a file.

## The output and the exit status

The export writes one line for each option to the standard output:

```
Wrote deck.pdf: 12 pages.
Wrote 12 PNG files to slides.
```

The exit status is 0. For an error, the export writes the message to the standard error,
and the exit status is 1.

| Error | Cause |
| --- | --- |
| `--pdf and --png need Chrome or Chromium. ...` | The export found no browser. Install one, or give its path in `EXPRESSO_CHROMIUM`. |
| `EXPRESSO_CHROMIUM gives <path>, and that file does not exist.` | The variable gives a wrong path. |
| `The browser <path> did not end in 120 s. ...` | The browser did not write the file. Give a different browser, such as the headless shell of Playwright. |
| `The browser <path> made a picture of 500 × 667, and not of 375 × 667. ...` | Chrome cannot make a window narrower than 500 pixels. Use the headless shell of Playwright, or a larger `--size`. |
| `--pdf-pages needs --pdf` | An option of the PDF with no `--pdf`. `--png-steps` needs `--png` in the same way. |
| `--pdf-paper needs --pdf-pages handout` | The pages of the slides have the size of `--size`, and no paper. |
| `--pdf and --png do not go with --watch or --check` | Run the check or the watch mode in a different command. |
| `--pdf and --png take one --size` | The command gives `--size` more than one time. |

## The browser

The export looks for the browser as `--check=layout` does: `EXPRESSO_CHROMIUM`, then the
browsers of Playwright, then Chrome and Chromium on the `PATH`, then the usual places on
macOS. See [The check option](check-option.md). The headless shell of Playwright starts
fast, and it gives each size.
