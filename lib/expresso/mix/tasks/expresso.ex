defmodule Mix.Tasks.Expresso do
  @shortdoc "Make one HTML document from a deck"

  @moduledoc """
  Make one HTML document from a deck

      $ mix expresso <input> [output]
      $ mix expresso <input> [output] --watch [--port <port>]
      $ mix expresso <input> [output] --check[=layout | =a11y | =browser] [--size <size>]...
      $ mix expresso <input> [output] --pdf <file> [--pdf-pages <pages>] [--pdf-steps all]
      $ mix expresso <input> [output] --png <directory> [--png-steps all] [--size <size>]

  `<input>` is the Elixir script of the deck, or `-` for the standard input.
  The script returns an `Expresso.Deck` struct, or a module that uses the DSL
  of `Expresso`.

  `[output]` is the file for the HTML, or `-` for the standard output. Without
  it, the task writes the HTML to the standard output.

  ## Watch mode

  With `--watch`, the task serves the document at `http://127.0.0.1:4100/`.
  Open that address in a browser. After each change to the deck file, or to an
  image, a diagram or a style sheet of the deck, the task renders the deck
  again. The page then reloads, and it shows the same step.

  With `[output]`, the task also writes the document to that file after each
  good render. When a render fails, the task writes the error, and the page
  keeps the last good document. The watch mode needs an input file. Stop it
  with Ctrl-C.

  ## Check mode

  With `--check`, the task renders the deck, checks it, and writes a report
  to the standard output. The exit status is 1 when the report has a problem,
  so a CI job can run the check. With `[output]`, the task also writes the
  document to that file. Each level runs the checks of the level before it:

    * `--check` - the render, the contrast of the theme, and the text for a
      screen reader. It needs no other tool.
    * `--check=layout` - also the layout check at each step, in a headless
      Chrome or Chromium at 1920 × 1080. Give the path of the browser in
      `EXPRESSO_CHROMIUM` when the task does not find it.
    * `--check=a11y` - also the rules of axe-core at each step and in each
      view. Run `npm install --save-dev axe-core` in the directory of the
      deck, or give the path of `axe.min.js` in `EXPRESSO_AXE`.
    * `--check=browser` - also the keys of the presenter in Playwright: each
      step, each view, the focus and the errors of the script. Add the Hex
      package `playwright_ex` to your project, and run
      `npm install --save-dev playwright axe-core` and
      `npx playwright install chromium` in the directory of the deck.

  A browser level checks the page at 1920 × 1080. Give `--size 1024x768` for
  another size, and give the option more than one time for more sizes. Each
  problem of one size only names its size.

  `mix expresso --install-check-tools` installs the npm packages and the
  browser of the browser levels into a directory of the user.
  `docs/how-to/check-a-deck.md` tells how to install each tool.

  ## Export

  With `--pdf <file>`, the task renders the deck, and a headless Chrome or
  Chromium writes a PDF of it. With `--png <directory>`, the browser writes a
  PNG file of each slide into that directory. The two options can go
  together. With `[output]`, the task also writes the document to that file.
  The task writes a line for each export to the standard output.

    * `--pdf deck.pdf` - one page for each slide, as the present view shows
      its last step, with the theme of the deck. The page has the size of
      `--size`, or 1920 × 1080.
    * `--pdf-pages handout` - the pages of the handout view, as the print
      dialog of the browser gives them, with the notes and the theme of
      paper. `--pdf-paper letter` gives letter paper, and the default is A4.
    * `--pdf-steps all` - a page for each step.
    * `--png slides` - one file for the last step of each slide, such as
      `slides/slide-3.png`, at the size of `--size`, or 1920 × 1080.
    * `--png-steps all` - one file for each step, such as
      `slides/slide-3-step-2.png`.

  The export needs the browser of `--check=layout`. Give its path in
  `EXPRESSO_CHROMIUM` when the task does not find it.
  `docs/how-to/export-a-deck.md` gives the steps.

  ## Options

    * `--watch` - serve the deck, and render it again after each change
    * `--port <port>` - the port for `--watch`, from 1 to 65535. The default
      is 4100.
    * `--check`, `--check=layout`, `--check=a11y`, `--check=browser` - check
      the deck, and write a report
    * `--size <width>x<height>` - a size of the page for a browser level of
      `--check`, such as `1024x768`, or the size of the export. The default
      is 1920 × 1080.
    * `--pdf <file>` - write a PDF of the deck
    * `--pdf-pages slides`, `--pdf-pages handout` - the form of the pages of
      the PDF. The default is `slides`.
    * `--pdf-steps all` - a page of the PDF for each step
    * `--pdf-paper a4`, `--pdf-paper letter` - the paper of the handout form.
      The default is `a4`.
    * `--png <directory>` - write a PNG file of each slide
    * `--png-steps all` - a PNG file for each step
    * `-h`, `--help` - show this help
    * `--version` - show the version of Expresso
    * `--install-check-tools` - install the tools of the browser levels of
      `--check`. It needs Node and npm.

  Each other argument that starts with `-` is an error, and so is a third
  path. A path that starts with `-` needs a directory in front of it, such as
  `./-deck.exs`.

  ## Exit status

  The task writes the usage text and each error message to the standard
  error, and the exit status is then 1. With `--check`, a problem in the
  report also gives the exit status 1. An export that cannot write a file
  gives the exit status 1 too. When the standard output closes
  before the task writes all the HTML, as for `| head`, the task stops with no
  message, and the exit status is 0.
  """

  use Mix.Task

  @doc false
  @impl Mix.Task
  def run(args) do
    # The task gives its own `@moduledoc` as the help text, and it does not call
    # `Mix.Tasks.Help.run/1`. That function runs `deps.loadpaths` again, and
    # that task changes the working directory of the VM for a moment. In
    # `mix test`, a different test then does not find its files.
    #
    # A mix task that returns gives the exit status 0, so the task exits for
    # the status 1.
    case Expresso.CommandLine.run(args, "mix expresso", @moduledoc) do
      0 -> :ok
      1 -> exit({:shutdown, 1})
    end
  end
end
