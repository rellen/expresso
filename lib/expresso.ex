defmodule Expresso do
  @moduledoc """
  Documentation for `Expresso`.
  """
  use Spark.Dsl,
    default_extensions: [extensions: Expresso.Extension]

  def parse(module) do
    %Expresso.Deck{
      name: Spark.Dsl.Extension.get_opt(module, [:deck], :name),
      slides: Spark.Dsl.Extension.get_entities(module, [:deck])
    }
  end

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
          {deck, _} = evaluate_deck_file(input_path)
          {:ok, Expresso.Deck.render(deck)}

        _ ->
          {:error, "Couldn't find input file"}
      end

    case result do
      {:ok, rendered} ->
        unless output_path == nil do
          write_to_file(rendered, output_path)
        else
          IO.puts(rendered)
        end

        :ok

      {:error, msg} = err ->
        IO.puts(msg)
        err
    end
  end

  # sobelow_skip ["RCE"]
  defp evaluate_deck_file(input_path) do
    Code.eval_file(input_path)
  end

  # sobelow_skip ["Traversal"]
  defp write_to_file(rendered, output_path) do
    File.write(output_path, rendered)
  end
end
