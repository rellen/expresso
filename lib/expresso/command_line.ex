defmodule Expresso.CommandLine do
  @moduledoc """
  Reads and runs the command line of `mix expresso` and of the binary

  The two commands take the same arguments:

      <input> [output] [--watch [--port <port>] | --check[=<level>] [--size <size>]...]
              [--help | -h] [--version] [--install-check-tools]

  `parse/1` reads the arguments, and `run/3` runs them. The mix task and the
  binary both call `run/3`, so the two commands agree.
  """

  # The version in `mix.exs`. The binary has no `Mix`, so the value comes in at
  # compile time.
  @version Mix.Project.config()[:version]

  # The levels of `--check`. Each level runs the checks of the level before it.
  @check_levels %{"layout" => :layout, "a11y" => :a11y, "browser" => :browser}

  # The port of the watch mode without `--port`. Phoenix uses 4000, so a
  # Phoenix application and a deck can run at the same time.
  @default_port 4100

  @doc """
  Read the arguments of a command line

  The function returns the first of these results that applies:

    * `:help` for `--help` or `-h` in any position.
    * `:version` for `--version` in any position.
    * `:install_check_tools` for `--install-check-tools` alone. With another
      argument, the option is an error.
    * `{:error, message}` for an unknown option, a third path, a bad
      `--port` or a bad level of `--check`. Each argument that starts with
      `-` is an option, except `-` alone. `--port` without `--watch` is an
      error too, and so is `--check` with `--watch`. An output path that
      names the input file is an error in each mode, because the HTML would
      replace the deck.
    * `{:check, level, input, output, sizes}` for `--check`. The level is
      `:basic` for `--check`, `:layout` for `--check=layout`, `:a11y` for
      `--check=a11y` and `:browser` for `--check=browser`. The check needs an
      input, and it writes its report to the standard output, so `-` is an
      error for the output. `sizes` holds a tuple `{width, height}` for each
      `--size 1280x720` or `--size=1280x720`, in sequence, and it is `[]`
      without the option. `--size` needs a browser level.
    * `{:watch, input, output, port}` for `--watch`. The port comes from
      `--port 4200` or `--port=4200`, and it is 4100 without that option. The
      watch mode needs an input file, and it does not write to the standard
      output, so `-` is an error for either path.
    * `{:paths, input, output}` otherwise. A missing path is `nil`, and `-`
      gives the standard input or the standard output.

  A path that starts with `-` needs a directory in front of it, such as
  `./-deck.exs`.

      iex> Expresso.CommandLine.parse(["deck.exs", "deck.html"])
      {:paths, "deck.exs", "deck.html"}

      iex> Expresso.CommandLine.parse(["deck.exs", "--watch"])
      {:watch, "deck.exs", nil, 4100}

      iex> Expresso.CommandLine.parse(["deck.exs", "deck.html", "--watch", "--port", "4200"])
      {:watch, "deck.exs", "deck.html", 4200}

      iex> Expresso.CommandLine.parse(["deck.exs", "--check=layout"])
      {:check, :layout, "deck.exs", nil, []}

      iex> Expresso.CommandLine.parse(["deck.exs", "--check=layout", "--size", "1280x720"])
      {:check, :layout, "deck.exs", nil, [{1280, 720}]}

      iex> Expresso.CommandLine.parse(["deck.exs", "-h"])
      :help

      iex> Expresso.CommandLine.parse(["--version"])
      :version

      iex> Expresso.CommandLine.parse(["--install-check-tools"])
      :install_check_tools

      iex> Expresso.CommandLine.parse(["--verbose"])
      {:error, "Unknown option: --verbose"}

      iex> Expresso.CommandLine.parse(["deck.exs", "deck.html", "notes.html"])
      {:error, "Unexpected argument: notes.html"}
  """
  @spec parse([String.t()]) ::
          :help
          | :version
          | :install_check_tools
          | {:paths, String.t() | nil, String.t() | nil}
          | {:watch, String.t(), String.t() | nil, :inet.port_number()}
          | {:check, Expresso.Check.level(), String.t(), String.t() | nil,
             [Expresso.Check.size()]}
          | {:error, String.t()}
  def parse(args) do
    cond do
      Enum.any?(args, &(&1 in ["--help", "-h"])) ->
        :help

      "--version" in args ->
        :version

      args == ["--install-check-tools"] ->
        :install_check_tools

      "--install-check-tools" in args ->
        {:error, "--install-check-tools takes no other argument"}

      true ->
        args |> take_options(%{watch: false, port: nil, check: nil, sizes: []}, []) |> command()
    end
  end

  # Take `--watch`, `--port`, `--check` and `--size` out of the arguments. The
  # other arguments keep their order.
  defp take_options(["--watch" | rest], options, args),
    do: take_options(rest, %{options | watch: true}, args)

  defp take_options(["--port", value | rest], options, args),
    do: take_port(value, rest, options, args)

  defp take_options(["--port"], _options, _args), do: {:error, "--port needs a number"}

  defp take_options(["--port=" <> value | rest], options, args),
    do: take_port(value, rest, options, args)

  defp take_options(["--check" | rest], options, args),
    do: take_options(rest, %{options | check: :basic}, args)

  defp take_options(["--check=" <> level | rest], options, args) do
    case Map.fetch(@check_levels, level) do
      {:ok, level} -> take_options(rest, %{options | check: level}, args)
      :error -> {:error, "Unknown level of --check: #{level}. Give layout, a11y or browser."}
    end
  end

  defp take_options(["--size", value | rest], options, args),
    do: take_size(value, rest, options, args)

  defp take_options(["--size"], _options, _args),
    do: {:error, "--size needs a width and a height, such as 1280x720"}

  defp take_options(["--size=" <> value | rest], options, args),
    do: take_size(value, rest, options, args)

  defp take_options([arg | rest], options, args),
    do: take_options(rest, options, [arg | args])

  defp take_options([], options, args), do: {options, Enum.reverse(args)}

  defp take_port(value, rest, options, args) do
    case Integer.parse(value) do
      {port, ""} when port in 1..65_535 -> take_options(rest, %{options | port: port}, args)
      _other -> {:error, "Invalid port: #{value}"}
    end
  end

  # A size of the window, such as `1280x720`. Each side is from 200 to 8000
  # pixels.
  defp take_size(value, rest, options, args) do
    with [width, height] <- String.split(value, ["x", "×"]),
         {width, ""} when width in 200..8000 <- Integer.parse(width),
         {height, ""} when height in 200..8000 <- Integer.parse(height) do
      take_options(rest, %{options | sizes: options.sizes ++ [{width, height}]}, args)
    else
      _other ->
        {:error,
         "Invalid size: #{value}. Give a width and a height from 200 to 8000, such as 1280x720."}
    end
  end

  # Make the result of `parse/1` from the watch options and the other
  # arguments.
  defp command({:error, _message} = error), do: error

  defp command({options, args}) do
    cond do
      option = Enum.find(args, &option?/1) -> {:error, "Unknown option: #{option}"}
      length(args) > 2 -> {:error, "Unexpected argument: #{Enum.at(args, 2)}"}
      same_file?(args) -> {:error, "The output file is the input file"}
      true -> mode(options, Enum.at(args, 0), Enum.at(args, 1))
    end
  end

  # An output path that names the input file replaces the deck with its HTML.
  # `-` names the standard input or the standard output, and not a file.
  defp same_file?([input, output]) when input != "-" and output != "-",
    do: Path.expand(input) == Path.expand(output)

  defp same_file?(_args), do: false

  # The mode of the command, from the options that `take_options/3` found.
  defp mode(%{watch: true, check: level}, _input, _output) when level != nil,
    do: {:error, "--check and --watch do not go together"}

  defp mode(%{check: level, sizes: [_ | _]}, _input, _output) when level in [nil, :basic],
    do: {:error, "--size needs --check=layout, --check=a11y or --check=browser"}

  defp mode(%{check: level, port: nil, sizes: sizes}, input, output) when level != nil,
    do: check(level, input, output, sizes)

  defp mode(%{watch: true, port: port}, input, output),
    do: watch(input, output, port || @default_port)

  defp mode(%{port: port}, _input, _output) when port != nil,
    do: {:error, "--port needs --watch"}

  defp mode(_options, input, output), do: {:paths, input, output}

  # `-` alone is a path, and each other argument that starts with `-` is an
  # option.
  defp option?("-" <> rest), do: rest != ""
  defp option?(_arg), do: false

  defp watch(input, _output, _port) when input in [nil, "-"],
    do: {:error, "--watch needs an input file"}

  defp watch(_input, "-", _port), do: {:error, "--watch cannot write to the standard output"}
  defp watch(input, output, port), do: {:watch, input, output, port}

  defp check(_level, nil, _output, _sizes), do: {:error, "--check needs an input"}

  defp check(_level, _input, "-", _sizes),
    do: {:error, "--check writes its report to the standard output, so give a file for the HTML"}

  defp check(level, input, output, sizes), do: {:check, level, input, output, sizes}

  @doc """
  Run a command line, and return its exit status

  `Mix.Tasks.Expresso` and `Expresso.BurritoEntryPoint` both call this
  function. `program` is the name of the command in the usage text, and `help`
  is the text for `--help`. For each result of `parse/1`:

    * `:help` writes `help` to the standard output. The exit status is 0.
    * `:version` writes the version to the standard output. The exit status
      is 0.
    * `:install_check_tools` calls `Expresso.Check.Tools.install/2`. The exit
      status is 1 for an error, and 0 otherwise.
    * `{:error, message}` writes the message and the usage text to the
      standard error. The exit status is 1.
    * `{:paths, nil, _}` writes the usage text to the standard error. The exit
      status is 1.
    * `{:paths, input, output}` calls `Expresso.main/2`, which writes each
      error message. The exit status is 1 for an error, and 0 otherwise. A
      standard output that closed, as for `| head`, is not an error.
    * `{:watch, input, output, port}` calls `Expresso.Watch.run/3`. That
      function returns only for an error, so the exit status is 1.
    * `{:check, level, input, output, sizes}` calls `Expresso.Check.run/4`. The exit
      status is 1 for a problem or an error, and 0 otherwise.

  The function does not catch an exception from the deck. The binary catches
  it and writes the message, and Mix writes it for the mix task.
  """
  @spec run([String.t()], String.t(), String.t()) :: 0 | 1
  def run(args, program, help) do
    case parse(args) do
      :help ->
        IO.write(help)
        0

      :version ->
        IO.puts(version())
        0

      :install_check_tools ->
        install_check_tools()

      {:error, message} ->
        IO.puts(:stderr, [message, ?\n, usage(program)])
        1

      {:paths, nil, _output_path} ->
        IO.puts(:stderr, usage(program))
        1

      {:paths, input_path, output_path} ->
        input_path |> Expresso.main(output_path) |> status()

      # The watch mode returns only for an error, and it writes the message.
      {:watch, input_path, output_path, port} ->
        {:error, _message} = Expresso.Watch.run(input_path, output_path, port: port)
        1

      {:check, level, input_path, output_path, sizes} ->
        Expresso.Check.run(input_path, output_path, level, sizes)
    end
  end

  defp install_check_tools do
    case Expresso.Check.Tools.install() do
      :ok ->
        0

      {:error, message} ->
        IO.puts(:stderr, message)
        1
    end
  end

  defp status(:ok), do: 0
  defp status({:error, :closed}), do: 0
  defp status({:error, _message}), do: 1

  @doc """
  Return the usage text of a command with the name `program`

      iex> Expresso.CommandLine.usage("mix expresso")
      "Usage: mix expresso <input> [output]"
  """
  @spec usage(String.t()) :: String.t()
  def usage(program), do: "Usage: #{program} <input> [output]"

  @doc """
  Return the text for `--version`: the name and the version of Expresso
  """
  @spec version() :: String.t()
  def version, do: "Expresso #{@version}"
end
