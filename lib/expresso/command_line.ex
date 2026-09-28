defmodule Expresso.CommandLine do
  @moduledoc """
  The arguments of the command line of `mix expresso` and of the binary

  The two commands take the same arguments: an input path, an optional output
  path, `--watch`, `--port`, `--help` or `-h`, and `--version`. This module
  reads them, so the two commands agree.
  """

  # The version of `mix.exs`. The binary has no `Mix`, so the value comes in at
  # compile time.
  @version Mix.Project.config()[:version]

  # The port of the watch mode without `--port`. Phoenix uses 4000, so a
  # Phoenix application and a deck can run at the same time.
  @default_port 4100

  @doc """
  Read the arguments of a command line

  The function returns `:help` for `--help` or `-h` in any position, and then
  `:version` for `--version` in any position. For a different argument that
  starts with `-`, it returns an error tuple with the message. The argument `-`
  alone is a path: `Expresso.main/2` reads it as the standard input or the
  standard output. A third path is an error too. Otherwise, the function
  returns the input path and the output path. A missing path is `nil`.

  With `--watch`, the function returns `{:watch, input, output, port}` for
  `Expresso.Watch.run/3`. `--port 4200` or `--port=4200` gives the port, and
  the port is 4100 without it. The watch mode needs an input file, and it does
  not write to the standard output, so `-` is an error with `--watch`.
  `--port` without `--watch` is an error too.

  A path that starts with `-` needs a directory in front of it, such as
  `./-deck.exs`.

      iex> Expresso.CommandLine.parse(["deck.exs", "deck.html"])
      {:paths, "deck.exs", "deck.html"}

      iex> Expresso.CommandLine.parse(["deck.exs", "--watch"])
      {:watch, "deck.exs", nil, 4100}

      iex> Expresso.CommandLine.parse(["deck.exs", "deck.html", "--watch", "--port", "4200"])
      {:watch, "deck.exs", "deck.html", 4200}

      iex> Expresso.CommandLine.parse(["deck.exs", "-h"])
      :help

      iex> Expresso.CommandLine.parse(["--version"])
      :version

      iex> Expresso.CommandLine.parse(["--verbose"])
      {:error, "Unknown option: --verbose"}

      iex> Expresso.CommandLine.parse(["deck.exs", "deck.html", "notes.html"])
      {:error, "Unexpected argument: notes.html"}
  """
  @spec parse([String.t()]) ::
          :help
          | :version
          | {:paths, String.t() | nil, String.t() | nil}
          | {:watch, String.t(), String.t() | nil, :inet.port_number()}
          | {:error, String.t()}
  def parse(args) do
    cond do
      Enum.any?(args, &(&1 in ["--help", "-h"])) -> :help
      "--version" in args -> :version
      true -> args |> watch_options(%{watch: false, port: nil}, []) |> paths()
    end
  end

  # Take `--watch` and `--port` out of the arguments. The other arguments keep
  # their order.
  defp watch_options(["--watch" | rest], options, args),
    do: watch_options(rest, %{options | watch: true}, args)

  defp watch_options(["--port", value | rest], options, args),
    do: port(value, rest, options, args)

  defp watch_options(["--port"], _options, _args), do: {:error, "--port needs a number"}

  defp watch_options(["--port=" <> value | rest], options, args),
    do: port(value, rest, options, args)

  defp watch_options([arg | rest], options, args), do: watch_options(rest, options, [arg | args])
  defp watch_options([], options, args), do: {options, Enum.reverse(args)}

  defp port(value, rest, options, args) do
    case Integer.parse(value) do
      {port, ""} when port in 1..65_535 -> watch_options(rest, %{options | port: port}, args)
      _other -> {:error, "Invalid port: #{value}"}
    end
  end

  defp paths({:error, _message} = error), do: error

  defp paths({options, args}) do
    cond do
      option = Enum.find(args, &option?/1) -> {:error, "Unknown option: #{option}"}
      length(args) > 2 -> {:error, "Unexpected argument: #{Enum.at(args, 2)}"}
      options.watch -> watch(Enum.at(args, 0), Enum.at(args, 1), options.port || @default_port)
      options.port -> {:error, "--port needs --watch"}
      true -> {:paths, Enum.at(args, 0), Enum.at(args, 1)}
    end
  end

  defp watch(input, _output, _port) when input in [nil, "-"],
    do: {:error, "--watch needs an input file"}

  defp watch(_input, "-", _port), do: {:error, "--watch cannot write to the standard output"}
  defp watch(input, output, port), do: {:watch, input, output, port}

  @doc """
  The usage text of a command with the name `program`

      iex> Expresso.CommandLine.usage("mix expresso")
      "Usage: mix expresso <input> [output]"
  """
  @spec usage(String.t()) :: String.t()
  def usage(program), do: "Usage: #{program} <input> [output]"

  @doc """
  The text of `--version`: the name and the version of Expresso
  """
  @spec version() :: String.t()
  def version, do: "Expresso #{@version}"

  defp option?("-" <> rest), do: rest != ""
  defp option?(_arg), do: false
end
