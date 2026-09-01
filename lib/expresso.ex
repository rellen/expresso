defmodule Expresso do
  @moduledoc """
  Expresso makes one HTML document from a deck

  A deck comes from one of two input paths. A script builds an `Expresso.Deck`
  struct with function calls, or a module declares a deck with the DSL of this
  module. `to_deck/1` accepts the value of either path.

  `main/2` is the entry point of the command `mix expresso <input> [output]` and
  of the binary that Burrito makes. It reads the input script, it makes the HTML,
  and it writes the HTML to the output path or to the standard output.

  `docs/architecture.md` gives the render pipeline, the templates and the
  elements.
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
  Make an HTML document from an input script

  The function writes the HTML to `output_path`. With `nil` as the output path,
  the function writes the HTML to the standard output.

  With `nil` as the input path, the function writes the usage text and returns an
  error tuple. The mix task gives `nil` when the command has no argument.
  """
  @spec main(Path.t() | nil, Path.t() | nil) :: :ok | {:error, String.t()}
  def main(input_path, output_path \\ nil)

  def main(nil, _output_path) do
    message = "Usage: mix expresso <input> [output]"
    IO.puts(message)
    {:error, message}
  end

  def main(input_path, output_path) do
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
