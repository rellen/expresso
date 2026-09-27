defmodule Expresso.CommandLine do
  @moduledoc """
  The arguments of the command line of `mix expresso` and of the binary

  The two commands take the same arguments: an input path, an optional output
  path, and `--help` or `-h`. This module reads them, so the two commands agree.
  """

  @doc """
  Read the arguments of a command line

  The function returns `:help` for `--help` or `-h` in any position. For a
  different argument that starts with `-`, it returns an error tuple with the
  message. The argument `-` alone is a path. Otherwise, the function returns the
  input path and the output path. A missing path is `nil`.

  A path that starts with `-` needs a directory in front of it, such as
  `./-deck.exs`.

      iex> Expresso.CommandLine.parse(["deck.exs", "deck.html"])
      {:paths, "deck.exs", "deck.html"}

      iex> Expresso.CommandLine.parse(["deck.exs", "-h"])
      :help

      iex> Expresso.CommandLine.parse(["--version"])
      {:error, "Unknown option: --version"}
  """
  @spec parse([String.t()]) ::
          :help | {:paths, String.t() | nil, String.t() | nil} | {:error, String.t()}
  def parse(args) do
    cond do
      Enum.any?(args, &(&1 in ["--help", "-h"])) -> :help
      option = Enum.find(args, &option?/1) -> {:error, "Unknown option: #{option}"}
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

  defp option?("-" <> rest), do: rest != ""
  defp option?(_arg), do: false
end
