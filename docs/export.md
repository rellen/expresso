# The export

This document gives the design for the export of a deck from the command line: a PDF, and
a PNG file of each slide. The code contains this design. Issue #407 asked for it. The
document records ten decisions, and each is settled. Its last section, "The result", tells
what changed during the work.

## The problem

A PDF of a deck came from the print dialog of the browser. The author opened the deck,
pressed `p`, selected the steps with `a`, and printed. A build cannot do these steps, so a
workflow could not publish the slides of a talk. Slidev and Marp export a PDF and pictures
from the command line.

## The plan

1. `Expresso.CommandLine` reads `--pdf`, `--png` and their options, and it calls
   `Expresso.Export.run/3`.
2. The export finds Chrome or Chromium with `Expresso.Check.Browser.find/3`, and it
   renders the deck.
3. For the PDF, the browser prints a copy of the document. The copy has attributes on its
   `html` element and a rule for the size of the page, and the style sheet reads the
   attributes in its rules for paper.
4. For each PNG file, the browser opens the present view at one step, and it takes a
   picture of the window.

## The decisions

Each decision is settled.

1. **Two options, `--pdf` and `--png`.** The maintainer made this decision. One command
   can then write the HTML, the PDF and the pictures. One option `--export=pdf` needs a
   second argument for the path, and it cannot give two exports.
2. **The command line of the browser, and not Playwright.** The issue named the tools of
   `--check=browser`: Node, the npm package `playwright` and the Hex package
   `playwright_ex`. Chrome prints a PDF with `--print-to-pdf`, and it takes a picture with
   `--screenshot`. The export thus needs only the browser of `--check=layout`, and a
   workflow that publishes slides needs no Node. One run of the headless shell takes
   approximately 0.25 s.
3. **The PDF has one page for each slide, with the theme of the deck.** The maintainer made
   this decision. A viewer of a PDF of a talk expects pages that look like the slides.
   `--pdf-pages handout` gives the handout view, as the print dialog does.
4. **The page of a slide has the size of the window, in pixels.** A slide has no fixed
   size: the text is 48 px high, and the window gives the space. A page of
   1920 × 1080 px with no margin gives the layout of a window of that size, which is the
   size of `--check`. `--size` gives a different size, and so a different layout.
5. **Paper keeps its rules, and attributes change them.** The rules of the style sheet for
   paper show the handout view. The export writes `data-print="slides"` on the `html`
   element of its copy, and the rules for that attribute give each page the height of the
   page, the text of the screen and no notes. The alternative is a second document for
   the PDF, with its own rules. The presenter script does not know the attributes, so it
   cannot remove them.
6. **The theme of paper is a rule with a condition.** Paper gets the default theme,
   because a dark theme on paper uses much ink. A document with `data-print="slides"` is
   not for paper, so the rule of the theme of paper does not apply to it. The condition
   is in `:where`, so the rule has the weight that it had before.
7. **`--pdf-steps all` and `--png-steps all`.** Without them, the pages of the slides and
   the PNG files show the last step of each slide, which is the complete slide. The handout
   view shows the steps of the `handout` option. `all` gives each step in each form.
8. **A PNG file is a picture of the present view at one step.** The address of a step,
   such as `#3.2`, opens the present view at that step. The browser asks for reduced
   motion, so the page has no change in progress. The copy of the document hides the
   progress bar, because a picture is not a talk.
9. **The name of a file holds the number of the slide in the address.** A hidden slide has
   no file, so the numbers can have a gap, and `slide-4.png` is always the slide of
   `#4.1`. Each number has the digits of the largest number, so the names sort.
10. **The export writes a file only when the browser made it.** The browser writes into a
    private directory, and the export then writes the file to its path. An error leaves
    no part of a file, and the export gives one line for each file to the standard
    output, so a build log shows the number of pages.

## The result

The code follows the plan, with these changes:

1. **`--pdf-paper`.** The print dialog of a browser knows the paper of the user. The
   command line does not, and Chrome uses letter paper. The handout form therefore takes
   `a4`, which is the default, or `letter`.
2. **No `--pdf-theme`.** The issue named an option that keeps the theme of the deck in the
   handout form. The pages of the slides keep the theme, so the option has no use yet.
3. **A chart or a tree with frames shows one frame on a page of a slide.** Paper shows
   each frame in a grid, because paper cannot move. A page of a slide shows the frame of
   its step, as the screen does.
4. **`Expresso.Check.Browser.command/4` and `window/4`.** The check ran the browser in a
   private function. The export needs the same run with different arguments, and the
   same search for the size of the window, so the two functions are public.
5. **The job `binary` of the workflow installs a browser.** One test of `test/release/`
   exports a deck with the binary. The binary gets a new home directory for each run, so
   the test gives it the path of the browser.

`docs/reference/export-options.md` gives the options, and `docs/how-to/export-a-deck.md`
gives the steps.

## The limits

- A deck with a light and a dark variant of its theme gives the light variant.
- The export takes one size. A second size needs a second command.
- A PDF of the slides holds no notes. The handout form holds them.
