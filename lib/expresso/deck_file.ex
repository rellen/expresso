defmodule Expresso.DeckFile do
  @moduledoc """
  Reads the files that a deck names, and records their paths for the watch mode

  A deck can name an image, a diagram, a code file, a page, a style sheet and
  a file of a `url()` of the style sheet. The module of each reads the file
  with `read/1` or `read!/2`. A module that puts the file into the document
  as text reads it with `read_text/1` or `read_text!/2`, which also make sure
  that the file is UTF-8. An element gives the message of `read_error/3` for a
  file that it cannot read.

  `Expresso.Watch` renders a deck inside `track/1`. That function returns each
  path that `read/1` read during the render, so the watch mode knows which
  files to watch. Outside `track/1`, `read/1` records nothing. Thus those
  modules need no code for the watch mode.

  `track/1` keeps the paths in the process dictionary. Two renders in two
  processes therefore keep their paths apart.
  """

  @key {__MODULE__, :paths}

  @typedoc "The reason that a file of a deck cannot be read"
  @type reason :: File.posix() | :not_utf8

  @doc """
  Read a file that a deck names

  A relative path starts from the working directory of the command.
  `Expresso.PathTransformer` joins each path of a deck with the `root` option
  to that directory first. The function returns the result of `File.read/1`.
  """
  @spec read(Path.t()) :: {:ok, binary()} | {:error, File.posix()}
  # The person who runs the command wrote the deck, and `Expresso.main/2`
  # evaluates the deck with `Code.eval_file/1`. The deck thus has the rights of
  # that person. A path in the deck is not input from a different user, and the
  # author can name a file in any directory.
  # sobelow_skip ["Traversal.FileModule"]
  def read(path) do
    record(path)
    File.read(path)
  end

  @doc """
  Read a file that a deck names, and raise for a file that it cannot read

  The `noun` names the file in the message, such as `"diagram"`. The message
  is the text of `read_error/3`.
  """
  @spec read!(Path.t(), String.t()) :: binary()
  def read!(path, noun) do
    case read(path) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise ArgumentError, read_error(path, noun, reason)
    end
  end

  @doc """
  Read a text file that a deck names, and make sure that it is UTF-8

  The document is UTF-8, and the lexers read only UTF-8. The function returns
  `{:error, :not_utf8}` for a file that has a different encoding, such as
  Latin-1. A different error is the error of `read/1`.
  """
  @spec read_text(Path.t()) :: {:ok, String.t()} | {:error, reason()}
  def read_text(path) do
    with {:ok, bytes} <- read(path) do
      if String.valid?(bytes), do: {:ok, bytes}, else: {:error, :not_utf8}
    end
  end

  @doc """
  Read a text file that a deck names, and raise for a file that it cannot read

  The function is `read!/2` for a file that must be UTF-8, as `read_text/1`
  tells.
  """
  @spec read_text!(Path.t(), String.t()) :: String.t()
  def read_text!(path, noun) do
    case read_text(path) do
      {:ok, text} -> text
      {:error, reason} -> raise ArgumentError, read_error(path, noun, reason)
    end
  end

  @doc """
  Return the message for a file of a deck that cannot be read

  Each element that reads a file gives this message: the noun, the path, the
  reason from `:file.format_error/1`, and where a relative path starts.

      iex> Expresso.DeckFile.read_error("a.svg", "diagram", :enoent)
      ~s(cannot read the diagram "a.svg": no such file or directory. A path is relative to ) <>
        "the working directory of the command, or to the root option of the deck."

  For `:not_utf8`, the message tells the user to save the file as UTF-8.

      iex> Expresso.DeckFile.read_error("legacy.toml", "code file", :not_utf8)
      ~s(cannot read the code file "legacy.toml": the file is not UTF-8 text. ) <>
        "Save the file with the UTF-8 encoding."
  """
  @spec read_error(Path.t(), String.t(), reason()) :: String.t()
  def read_error(path, noun, :not_utf8) do
    "cannot read the #{noun} \"#{path}\": the file is not UTF-8 text. " <>
      "Save the file with the UTF-8 encoding."
  end

  def read_error(path, noun, reason) do
    "cannot read the #{noun} \"#{path}\": #{:file.format_error(reason)}. " <>
      "A path is relative to the working directory of the command, or to the root option " <>
      "of the deck."
  end

  @doc """
  Run a function, and return its result with each path that `read/1` read

  The paths are in the order of their first read, and each path is in the list
  one time. A read that failed is in the list too, because the file can appear
  later. An exception, an exit or a throw goes on to the caller.
  """
  @spec track((-> result)) :: {result, [Path.t()]} when result: var
  def track(function) do
    previous = Process.put(@key, [])

    try do
      result = function.()
      {result, @key |> Process.get() |> Enum.reverse() |> Enum.uniq()}
    after
      if previous == nil, do: Process.delete(@key), else: Process.put(@key, previous)
    end
  end

  defp record(path) do
    case Process.get(@key) do
      nil -> :ok
      paths -> Process.put(@key, [path | paths])
    end
  end
end
