defmodule Expresso.Element.Diagram.Cache do
  @moduledoc """
  Keeps the SVG of each graph and the MathML of each formula from one render
  of the watch mode to the next

  D2 with ELK takes some seconds for a graph, and the watch mode renders the
  whole deck after each change. Without a cache, a change to the text of one
  slide would run each tool of the deck again.

  `Expresso.Watch` calls `run/2` around each render, with the cache of the
  render before. `fetch/2` returns the value of a key from that cache, or it
  calls its function. `run/2` returns the entries that the render used, so the
  cache holds only the graphs of the deck as it is now. A render outside
  `run/2`, such as a render from the command line, runs each tool one time
  and keeps nothing.

  The cache is in the process dictionary of the render, as the record of
  `Expresso.DeckFile.track/1` is. A render runs in one process.
  """

  @key {__MODULE__, :cache}

  @typedoc "The entries of a cache, by key"
  @type t :: %{binary() => term()}

  @doc """
  Run a render with the entries of the render before

  The function returns the result of the render and the entries that the
  render used.
  """
  @spec run(t(), (-> result)) :: {result, t()} when result: var
  def run(cache, function) do
    previous = Process.put(@key, {cache, %{}})

    try do
      result = function.()
      {_old, used} = Process.get(@key)
      {result, used}
    after
      if previous == nil, do: Process.delete(@key), else: Process.put(@key, previous)
    end
  end

  @doc """
  Return the value of a key, or call the function and keep its value

  Outside `run/2`, the function calls `function` each time. The key is a term,
  and the function keeps a hash of it.
  """
  @spec fetch(term(), (-> value)) :: value when value: var
  def fetch(key, function) do
    case Process.get(@key) do
      nil ->
        function.()

      {old, used} ->
        hash = hash(key)

        value =
          case Map.fetch(used, hash) do
            {:ok, value} -> value
            :error -> Map.get_lazy(old, hash, function)
          end

        Process.put(@key, {old, Map.put(used, hash, value)})
        value
    end
  end

  @doc """
  Return the value of each key, and call the function one time for the keys
  that the cache does not hold

  `function` takes the list of the missing keys, in the order of `keys`, and
  returns one value for each. A tool that makes many values in one run, such
  as Temml for the formulas of a deck, then runs one time. Outside `run/2`,
  the function calls `function` with each key.
  """
  @spec fetch_many([term()], ([term()] -> [value])) :: [value] when value: var
  def fetch_many(keys, function) do
    case Process.get(@key) do
      nil -> function.(keys)
      {old, used} -> fetch_many(keys, function, old, used)
    end
  end

  defp fetch_many(keys, function, old, used) do
    hashes = Enum.map(keys, &hash/1)
    known = Map.merge(old, used)

    missing =
      keys
      |> Enum.zip(hashes)
      |> Enum.reject(fn {_key, hash} -> Map.has_key?(known, hash) end)
      |> Enum.uniq_by(fn {_key, hash} -> hash end)

    known = Map.merge(known, make(missing, function))
    values = Enum.map(hashes, &Map.fetch!(known, &1))
    Process.put(@key, {old, Map.merge(used, Map.new(Enum.zip(hashes, values)))})
    values
  end

  # The values of the missing keys, by hash, from one call of the function.
  defp make([], _function), do: %{}

  defp make(missing, function) do
    {keys, hashes} = Enum.unzip(missing)
    hashes |> Enum.zip(function.(keys)) |> Map.new()
  end

  defp hash(key), do: :crypto.hash(:sha256, :erlang.term_to_binary(key))
end
