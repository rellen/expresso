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
    progress = Spark.Dsl.Extension.get_opt(module, [:deck], :progress, true)
    handout = Spark.Dsl.Extension.get_opt(module, [:deck], :handout, :all)
    print_notes = Spark.Dsl.Extension.get_opt(module, [:deck], :print_notes, true)
    slide_numbers = Spark.Dsl.Extension.get_opt(module, [:deck], :slide_numbers, false)
    duration = Spark.Dsl.Extension.get_opt(module, [:deck], :duration)
    transition = Spark.Dsl.Extension.get_opt(module, [:deck], :transition, :fade)
    effect = Spark.Dsl.Extension.get_opt(module, [:deck], :effect, :fade)
    speed = Spark.Dsl.Extension.get_opt(module, [:deck], :speed)
    easing = Spark.Dsl.Extension.get_opt(module, [:deck], :easing)
    css = Spark.Dsl.Extension.get_opt(module, [:deck], :css)

    slides =
      module
      |> Spark.Dsl.Extension.get_entities([:deck])
      |> Enum.map(&Expresso.Slide.put_options_in_metadata/1)

    name
    |> Expresso.Deck.new(
      %{
        progress: progress,
        handout: handout,
        print_notes: print_notes,
        slide_numbers: slide_numbers,
        duration: duration,
        transition: transition,
        effect: effect,
        speed: speed,
        easing: easing,
        css: css
      },
      slides
    )
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

  The function writes the HTML to `output_path`. With `nil` or `-` as the output
  path, the function writes the HTML to the standard output. With `-` as the
  input path, the function reads the script from the standard input.

  With `nil` as the input path, the function writes the usage text to the
  standard error and returns an error tuple. The mix task gives `nil` when the
  command has no argument.

  For each other error, the function writes the message to the standard error
  and returns an error tuple. The standard output then holds no text. A failed
  write of the output file is an error too.

  When the standard output closes before the function writes all the HTML, as
  for `| head`, the function returns `{:error, :closed}` and writes no message.
  """
  @spec main(Path.t() | nil, Path.t() | nil) :: :ok | {:error, String.t() | :closed}
  def main(input_path, output_path \\ nil)

  def main(nil, _output_path), do: error(Expresso.CommandLine.usage("mix expresso"))

  def main(input_path, output_path) do
    with {:ok, rendered} <- render_input(input_path),
         :ok <- output(rendered, output_path) do
      :ok
    else
      {:error, :closed} = closed -> closed
      {:error, message} -> error(message)
    end
  end

  defp render_input("-") do
    case IO.read(:stdio, :eof) do
      {:error, reason} ->
        {:error, "Couldn't read the standard input: #{:file.format_error(reason)}"}

      # Empty input gives `:eof`, and an empty script gives `nil`.
      :eof ->
        render_value(evaluate_deck_source(""))

      source ->
        render_value(evaluate_deck_source(source))
    end
  end

  defp render_input(input_path) do
    case File.stat(input_path) do
      {:ok, _stat} -> render_value(evaluate_deck_file(input_path))
      _ -> {:error, "Couldn't find input file"}
    end
  end

  defp render_value({value, _bindings}) do
    with {:ok, deck} <- to_deck(value), do: {:ok, Expresso.Deck.render(deck)}
  end

  # When the reader of the standard output stops, as `| head` does, the writer
  # of the VM gets `epipe` and stops. `IO.puts/1` then raises `:terminated`.
  defp output(rendered, nil) do
    ignore_closed_stdout_report()
    IO.puts(rendered)
  rescue
    error in ErlangError ->
      if error.original == :terminated,
        do: {:error, :closed},
        else: reraise(error, __STACKTRACE__)
  end

  defp output(rendered, "-"), do: output(rendered, nil)

  defp output(rendered, output_path) do
    case write_to_file(rendered, output_path) do
      :ok -> :ok
      {:error, reason} -> {:error, "Couldn't write output file: #{:file.format_error(reason)}"}
    end
  end

  defp error(message) do
    IO.puts(:stderr, message)
    {:error, message}
  end

  # In `mix expresso`, OTP logs "Writer crashed (epipe)" when the reader of the
  # standard output stops. The default handler of the logger then fails to
  # write to the standard output, and it writes a second message. This filter
  # drops that one report, so a closed standard output gives no message. The
  # binary does not come here for a closed pipe: `Expresso.SignalHandler` tells
  # why.
  defp ignore_closed_stdout_report do
    filter = {&__MODULE__.closed_stdout_filter/2, []}

    case :logger.add_primary_filter(:expresso_closed_stdout, filter) do
      :ok -> :ok
      {:error, {:already_exist, :expresso_closed_stdout}} -> :ok
    end
  end

  @doc false
  @spec closed_stdout_filter(:logger.log_event(), term()) :: :logger.filter_return()
  def closed_stdout_filter(
        %{meta: %{mfa: {:user_drv, _, _}}, msg: {~c"Writer crashed (~p)", [:epipe]}},
        _extra
      ),
      do: :stop

  def closed_stdout_filter(_event, _extra), do: :ignore

  # sobelow_skip ["RCE"]
  defp evaluate_deck_file(input_path) do
    Code.eval_file(input_path)
  end

  # The script of the standard input. A warning or an error of the compiler
  # names the file "stdin".
  # sobelow_skip ["RCE"]
  defp evaluate_deck_source(source) do
    Code.eval_string(source, [], file: "stdin")
  end

  # sobelow_skip ["Traversal"]
  defp write_to_file(rendered, output_path) do
    File.write(output_path, rendered)
  end
end
