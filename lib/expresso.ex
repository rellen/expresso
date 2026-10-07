defmodule Expresso do
  @moduledoc """
  Expresso makes one HTML document from a deck

  A deck comes from one of two input paths. A module declares a deck with the
  DSL of this module, or a script makes an `Expresso.Deck` struct with the
  functions of `Expresso.Builder`. The two paths run the same transformers and
  verifiers. `to_deck/1` accepts the value of either path.

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
  def parse(module), do: from_dsl_state(module.spark_dsl_config())

  @doc """
  Make a deck from the state of the DSL

  The state comes from a module that uses the DSL, or from
  `Expresso.Builder.deck/2`. The transformers of the DSL already ran on it.
  """
  @spec from_dsl_state(map()) :: Expresso.Deck.t()
  def from_dsl_state(state) do
    option = &Spark.Dsl.Transformer.get_option(state, [:deck], &1, &2)

    slides =
      state
      |> Spark.Dsl.Transformer.get_entities([:deck])
      |> Enum.map(&Expresso.Slide.put_options_in_metadata/1)

    metadata = %{
      progress: option.(:progress, true),
      handout: option.(:handout, :all),
      print_notes: option.(:print_notes, true),
      slide_numbers: option.(:slide_numbers, false),
      duration: option.(:duration, nil),
      transition: option.(:transition, :fade),
      effect: option.(:effect, :fade),
      speed: option.(:speed, nil),
      easing: option.(:easing, nil),
      css: option.(:css, nil),
      theme: option.(:theme, :default)
    }

    # The templates and the renderer read a key when it is present, so the key
    # is present only for an option that the deck gives.
    metadata =
      Enum.reduce([:template, :slide_template, :root], metadata, fn key, metadata ->
        case option.(key, nil) do
          nil -> metadata
          template -> Map.put(metadata, key, template)
        end
      end)

    :name
    |> option.(nil)
    |> Expresso.Deck.new(metadata, slides)
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

  @doc """
  Make the HTML document of an input file, and give it

  The function gives `{:ok, html}`, or `{:error, message}` for a file that it
  cannot find or render. An exception, an exit or a throw of the script also
  gives an error tuple, so the function does not raise. The function writes
  nothing. `Expresso.Watch` renders the deck with this function after each
  change.
  """
  @spec render_file(Path.t()) :: {:ok, String.t()} | {:error, String.t()}
  def render_file(input_path) do
    render_input(input_path)
  catch
    kind, reason -> {:error, Exception.format_banner(kind, reason, __STACKTRACE__)}
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
