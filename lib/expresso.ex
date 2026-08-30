defmodule Expresso do
  @moduledoc """
  Documentation for `Expresso`.
  """
  use Spark.Dsl,
    default_extensions: [extensions: Expresso.Extension]

  @doc """
  Make a deck from a module that uses the DSL
  """
  @spec parse(module()) :: Expresso.Deck.t()
  def parse(module) do
    name = Spark.Dsl.Extension.get_opt(module, [:deck], :name)
    slides = Spark.Dsl.Extension.get_entities(module, [:deck])

    name
    |> Expresso.Deck.new(%{}, slides)
    |> Expresso.Deck.number_slides()
  end

  @doc """
  Make a deck from the value of an input script

  An input script returns one of three values. It returns a deck, or a module that
  uses the DSL, or the tuple of a `defmodule` expression.
  """
  @spec to_deck(term()) :: {:ok, Expresso.Deck.t()} | {:error, String.t()}
  def to_deck(%Expresso.Deck{} = deck), do: {:ok, deck}

  def to_deck({:module, module, _binary, _result}), do: to_deck(module)

  def to_deck(module) when is_atom(module) do
    if dsl_module?(module) do
      {:ok, parse(module)}
    else
      {:error, unknown_input_message()}
    end
  end

  def to_deck(_value), do: {:error, unknown_input_message()}

  defp dsl_module?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :spark_is, 0) and
      module.spark_is() == __MODULE__
  end

  defp unknown_input_message do
    "The input file must return an Expresso.Deck struct, or a module that uses Expresso"
  end

  @doc """
  present a deck
  """
  @spec present() :: no_return
  def present do
    raise "not implemented"
  end

  @doc """
  Load all the custom deck and slide templates
  """
  @spec load_templates() :: :ok
  def load_templates do
    templates = Path.wildcard("./priv/templates/{decks,slides}/*.exs")

    Kernel.ParallelCompiler.compile(templates, return_diagnostics: true)

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
          {value, _bindings} = evaluate_deck_file(input_path)

          case to_deck(value) do
            {:ok, deck} -> {:ok, Expresso.Deck.render(deck)}
            {:error, _message} = error -> error
          end

        _ ->
          {:error, "Couldn't find input file"}
      end

    case result do
      {:ok, rendered} ->
        if output_path == nil do
          IO.puts(rendered)
        else
          write_to_file(rendered, output_path)
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
