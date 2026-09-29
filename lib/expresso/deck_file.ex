defmodule Expresso.DeckFile do
  @moduledoc """
  The reader of the files that a deck names

  A deck can name files other than the deck file: an image, a diagram and a
  style sheet. `Expresso.Image`, `Expresso.Element.Diagram` and `Expresso.Css`
  read each of them with `read/1`, and each module makes its own message for an
  error.

  `tracking/1` runs a function, and it gives each path that `read/1` read in
  that function. `Expresso.Watch` renders the deck in `tracking/1`, so it knows
  the files of the deck. Outside `tracking/1`, `read/1` records nothing, so the
  three modules know nothing about the watch mode.

  The paths are in the dictionary of the process that renders, so two renders
  in two processes do not mix their paths.
  """

  @key {__MODULE__, :paths}

  @doc """
  Read a file that a deck names

  The path is relative to the working directory of the command. The function
  gives the result of `File.read/1`.
  """
  # The path comes from the deck, and the person who runs the command wrote the
  # deck. `Expresso.main/2` already evaluates that deck with `Code.eval_file/1`,
  # so the deck has the rights of that person. A path of the deck is not the
  # input of a different user, and the traversal of a directory is the behavior
  # that the author asks for.
  # sobelow_skip ["Traversal.FileModule"]
  @spec read(Path.t()) :: {:ok, binary()} | {:error, File.posix()}
  def read(path) do
    record(path)
    File.read(path)
  end

  @doc """
  Run a function, and give its result with each path that `read/1` read in it

  The paths come in the order of the first read, and each path comes one
  time. A read that fails counts too, because the file can appear later. An
  exception, an exit or a throw of the function goes on to the caller.
  """
  @spec tracking((-> result)) :: {result, [Path.t()]} when result: var
  def tracking(function) do
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
