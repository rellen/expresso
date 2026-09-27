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
  For an error, the exit status is 1.

  ## Options

    * `-h`, `--help` - show this help
  """

  use Mix.Task

  @doc false
  @impl Mix.Task
  def run(args) do
    if Enum.any?(args, &(&1 in ["--help", "-h"])) do
      Mix.Tasks.Help.run(["expresso"])
    else
      render(Enum.at(args, 0), Enum.at(args, 1))
    end
  end

  # `Expresso.main/2` writes the message of an error. A mix task that returns
  # gives the exit status 0, so the task exits with the status 1.
  defp render(input_path, output_path) do
    case Expresso.main(input_path, output_path) do
      :ok -> :ok
      {:error, _message} -> exit({:shutdown, 1})
    end
  end
end
