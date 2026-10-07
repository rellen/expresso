defmodule Expresso.DeckFile do
  @moduledoc """
  Reads the files that a deck names, and records their paths for the watch mode

  A deck can name an image, a diagram, a code file, a page, a style sheet and
  a file of a `url()` of the style sheet. The module of each reads the file
  with `read/1`, and each module writes its own error message.

  `Expresso.Watch` renders a deck inside `track/1`. That function returns each
  path that `read/1` read during the render, so the watch mode knows which
  files to watch. Outside `track/1`, `read/1` records nothing. Thus those
  modules need no code for the watch mode.

  `track/1` keeps the paths in the process dictionary. Two renders in two
  processes therefore keep their paths apart.
  """

  @key {__MODULE__, :paths}

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
