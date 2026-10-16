defmodule Expresso.Copies do
  @moduledoc """
  Gives each copy of an element in a document its own number

  The document holds one copy of each slide for the present view and one for
  each page of the handout view. A browser resolves a reference such as
  `url(#fill)` to the first element of the document with that `id`. Thus a
  diagram and the head of an arrow need different ids in each copy, and
  `next/0` returns the number for the next copy.

  `Expresso.Renderer.render/1` makes a document in `number/1`, which counts
  from 1. Thus the same deck gives the same document in each VM, and the
  binary of Burrito and `Expresso.main/2` write the same HTML.
  """

  @key {__MODULE__, :last}

  @doc """
  Run a function, and number the copies in it from 1

  After the function, the process gets its count from before again, also
  when the function raises an exception.

      iex> Expresso.Copies.number(fn -> {Expresso.Copies.next(), Expresso.Copies.next()} end)
      {1, 2}
  """
  @spec number((-> result)) :: result when result: var
  def number(function) do
    previous = Process.put(@key, 0)

    try do
      function.()
    after
      if previous == nil, do: Process.delete(@key), else: Process.put(@key, previous)
    end
  end

  @doc """
  Return the number of the next copy

  Outside `number/1`, the count is for the process. Each number is then
  unique in the process, but the first number depends on the renders before.
  """
  @spec next() :: pos_integer()
  def next do
    number = Process.get(@key, 0) + 1
    Process.put(@key, number)
    number
  end
end
