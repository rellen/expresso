defmodule Mix.Tasks.Expresso do
  @shortdoc "Make one HTML document from a deck"

  @moduledoc """
  Make one HTML document from a deck

      $ mix expresso <input> [output]
      $ mix expresso <input> [output] --watch [--port <port>]
      $ mix expresso <input> [output] --check[=layout | =a11y | =browser]

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

  `docs/how-to/check-a-deck.md` tells how to install each tool.

  ## Options

    * `--watch` - serve the deck, and render it again after each change
    * `--port <port>` - the port for `--watch`, from 1 to 65535. The default
      is 4100.
    * `--check`, `--check=layout`, `--check=a11y`, `--check=browser` - check
      the deck, and write a report
    * `-h`, `--help` - show this help
    * `--version` - show the version of Expresso

  Each other argument that starts with `-` is an error, and so is a third
  path. A path that starts with `-` needs a directory in front of it, such as
  `./-deck.exs`.

  ## Exit status

  The task writes the usage text and each error message to the standard
  error, and the exit status is then 1. With `--check`, a problem in the
  report also gives the exit status 1. When the standard output closes
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
