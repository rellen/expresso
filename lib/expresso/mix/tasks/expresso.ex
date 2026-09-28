defmodule Mix.Tasks.Expresso do
  @shortdoc "Make one HTML document from a deck"

  @moduledoc """
  Make one HTML document from a deck

      $ mix expresso <input> [output]

  `<input>` is the Elixir script of the deck. The script returns an
  `Expresso.Deck` struct, or a module that uses the DSL of `Expresso`.

  `[output]` is the file for the HTML. Without it, the task writes the HTML to
  the standard output.

  The task writes the usage text and each error message to the standard error.
  For an error, the exit status is 1. When the standard output closes before
  the task writes all the HTML, as for `| head`, the task stops with no message,
  and the exit status is 0.

  ## Options

    * `-h`, `--help` - show this help
    * `--version` - show the version of Expresso

  A different argument that starts with `-` is an error, and so is a third
  path. A path that starts with `-` needs a directory in front of it, such as
  `./-deck.exs`.
  """

  use Mix.Task

  alias Expresso.CommandLine

  @doc false
  @impl Mix.Task
  def run(args) do
    case CommandLine.parse(args) do
      # `Mix.Tasks.Help.run/1` runs `deps.loadpaths` again, and that task
      # changes the working directory of the VM for a moment. In `mix test`, a
      # different test then does not find its files. Therefore the task writes
      # the text of `mix help expresso` itself.
      :help ->
        IO.write(@moduledoc)

      :version ->
        IO.puts(CommandLine.version())

      {:error, message} ->
        IO.puts(:stderr, [message, ?\n, CommandLine.usage("mix expresso")])
        exit({:shutdown, 1})

      {:paths, input_path, output_path} ->
        render(input_path, output_path)
    end
  end

  # `Expresso.main/2` writes the message of an error. A mix task that returns
  # gives the exit status 0, so the task exits with the status 1.
  defp render(input_path, output_path) do
    case Expresso.main(input_path, output_path) do
      :ok -> :ok
      {:error, :closed} -> :ok
      {:error, _message} -> exit({:shutdown, 1})
    end
  end
end
