defmodule Expresso.CommandLine do
  @moduledoc """
  The arguments of the command line of `mix expresso` and of the binary

  The two commands take the same arguments: an input path, an optional output
  path, `--help` or `-h`, and `--version`. This module reads them, so the two
  commands agree.
  """

  # The version of `mix.exs`. The binary has no `Mix`, so the value comes in at
  # compile time.
  @version Mix.Project.config()[:version]

  @doc """
  Read the arguments of a command line

  The function returns `:help` for `--help` or `-h` in any position, and then
  `:version` for `--version` in any position. For a different argument that
  starts with `-`, it returns an error tuple with the message. The argument `-`
  alone is a path: `Expresso.main/2` reads it as the standard input or the
  standard output. A third path is an error too. Otherwise, the function
  returns the input path and the output path. A missing path is `nil`.

  A path that starts with `-` needs a directory in front of it, such as
  `./-deck.exs`.

      iex> Expresso.CommandLine.parse(["deck.exs", "deck.html"])
      {:paths, "deck.exs", "deck.html"}

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
          | {:error, String.t()}
  def parse(args) do
    cond do
      Enum.any?(args, &(&1 in ["--help", "-h"])) -> :help
      "--version" in args -> :version
      option = Enum.find(args, &option?/1) -> {:error, "Unknown option: #{option}"}
      length(args) > 2 -> {:error, "Unexpected argument: #{Enum.at(args, 2)}"}
      true -> {:paths, Enum.at(args, 0), Enum.at(args, 1)}
    end
  end

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
