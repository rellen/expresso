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

  The task writes the usage text and each error message to the standard error.
  For an error, the exit status is 1. When the standard output closes before
  the task writes all the HTML, as for `| head`, the task stops with no message,
  and the exit status is 0.

  With `--watch`, the task serves the document at `http://127.0.0.1:4100/`,
  and it renders the deck again after each change to a file of the deck. The
  page in the browser then reloads, and it shows the same step. With
  `[output]`, the task also writes the document to that file after each render
  that succeeds. A render that fails writes its message to the standard error,
  and the page keeps the last document. The watch mode needs an input file,
  and it runs until you stop it with Ctrl-C. `Expresso.Watch` gives the
  details.

  ## Options

    * `--watch` - serve the deck, and render it again after each change
    * `--port <port>` - the port of `--watch`, from 1 to 65535. The default is
      4100.
    * `-h`, `--help` - show this help
    * `--version` - show the version of Expresso

  A different argument that starts with `-` is an error, and so is a third
  path. A path that starts with `-` needs a directory in front of it, such as
  `./-deck.exs`.
  """

  use Mix.Task

  @doc false
  @impl Mix.Task
  def run(args) do
    # `Mix.Tasks.Help.run/1` runs `deps.loadpaths` again, and that task changes
    # the working directory of the VM for a moment. In `mix test`, a different
    # test then does not find its files. Therefore the task gives the text of
    # `mix help expresso` itself.
    #
    # A mix task that returns gives the exit status 0, so the task exits with
    # the status 1 for an error.
    case Expresso.CommandLine.run(args, "mix expresso", @moduledoc) do
      0 -> :ok
      1 -> exit({:shutdown, 1})
    end
  end
end
