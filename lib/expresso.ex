defmodule Expresso do
  @moduledoc """
  Documentation for `Expresso`.
  """

  @doc """
  present a deck
  """
  @spec present() :: no_return
  def present() do
    raise "not implemented"
  end

  @doc """
  Load all the custom deck and slide templates
  """
  @spec load_templates() :: :ok
  def load_templates() do
    templates = Path.wildcard("./priv/templates/{decks,slides}/*.exs")

    Kernel.ParallelCompiler.compile(templates)

    :ok
  end

  @doc """
  Main function
  """
  @spec main(Path.t(), Path.t() | nil) :: :ok | {:error, String.t()}
  def main(input_path, output_path \\ nil) do
    result =
      case File.stat(input_path) do
        {:ok, _stat} ->
          {deck, _} =
            Code.eval_file(input_path)

          {:ok, Expresso.Deck.render(deck)}

        _ ->
          {:error, "Couldn't find input file"}
      end

    case result do
      {:ok, rendered} ->
        unless output_path == nil do
          File.write(output_path, rendered)
        else
          IO.puts(rendered)
        end

        :ok

      {:error, msg} = err ->
        IO.puts(msg)
        err
    end
  end
end
