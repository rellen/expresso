defmodule Mix.Tasks.Expresso do
  @shortdoc "Make one HTML document from a deck"

  @moduledoc """
  Make one HTML document from a deck

      $ mix expresso <input> [output]
      $ mix expresso <input> [output] --watch [--port <port>]

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

  ## Options

    * `--watch` - serve the deck, and render it again after each change
    * `--port <port>` - the port for `--watch`, from 1 to 65535. The default
      is 4100.
    * `-h`, `--help` - show this help
    * `--version` - show the version of Expresso

  Each other argument that starts with `-` is an error, and so is a third
  path. A path that starts with `-` needs a directory in front of it, such as
  `./-deck.exs`.

  ## Exit status

  The task writes the usage text and each error message to the standard
  error, and the exit status is then 1. When the standard output closes
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
