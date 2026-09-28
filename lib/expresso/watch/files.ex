defmodule Expresso.Watch.Files do
  @moduledoc """
  The files of a deck in the watch mode, and their changes

  A render reads the deck file, and it can read more files: an image, a
  diagram and a style sheet. `Expresso.Image`, `Expresso.Element.Diagram` and
  `Expresso.Css` call `track/1` for each file that they read. `tracking/1`
  collects these paths for one render, so the watch mode knows the files of the
  deck.

  `snapshot/1` records the state of each file, and `changed?/2` compares two
  snapshots. The watch mode takes a snapshot two times each second. The size
  and the time of the last change come from the file system. That time has a
  resolution of one second, so a file that changed in the last two seconds
  also gets a digest of its bytes. `changed?/2` compares two digests only when
  both snapshots have one, so a second change in the same second is a change,
  and a digest that a later snapshot does not have is not a change.

  `docs/architecture.md` tells why the watch mode reads the file system and
  does not use the events of the operating system.
  """

  @key {__MODULE__, :read}

  # A file that changed in this number of seconds gets a digest of its bytes.
  @recent 2

  @typedoc "The state of each file of a deck"
  @type snapshot :: %{Path.t() => {integer(), non_neg_integer(), binary() | nil} | :missing}

  @doc """
  Record that a render reads the file at `path`

  The function does nothing outside `tracking/1`, so a render outside the
  watch mode records nothing.
  """
  @spec track(Path.t()) :: :ok
  def track(path) do
    case Process.get(@key) do
      nil -> :ok
      paths -> Process.put(@key, [path | paths])
    end

    :ok
  end

  @doc """
  Run a function, and give its result with each path that it gave to `track/1`

  The paths come in the order of the first read, and each path comes one
  time. An exception, an exit or a throw of the function goes on to the
  caller.
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

  @doc """
  Tell whether a file changed from one snapshot to the next

  A file changed when its time of change or its size is different, when it
  appears or goes, or when both snapshots have a digest and the digests are
  different. A path of only one snapshot is a change too.
  """
  @spec changed?(snapshot(), snapshot()) :: boolean()
  def changed?(old, new) do
    Map.keys(old) != Map.keys(new) or
      Enum.any?(new, fn {path, state} -> different?(Map.fetch!(old, path), state) end)
  end

  defp different?({time, size, old}, {time, size, new}),
    do: old != nil and new != nil and old != new

  defp different?(old, new), do: old != new

  @doc """
  Record the state of each file of a list

  A file that does not exist gets `:missing`, so a new file or a removed file
  also gives a different snapshot.
  """
  @spec snapshot([Path.t()]) :: snapshot()
  def snapshot(paths) do
    now = System.os_time(:second)
    Map.new(paths, fn path -> {path, state(path, now)} end)
  end

  # The paths come from the deck and from the command line, and the person who
  # runs the command wrote the deck. See `Expresso.Image`.
  # sobelow_skip ["Traversal.FileModule"]
  defp state(path, now) do
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{type: :regular, mtime: mtime, size: size}} ->
        {mtime, size, if(now - mtime <= @recent, do: digest(path))}

      _other ->
        :missing
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp digest(path) do
    case File.read(path) do
      # The digest only tells a change, so MD5 is sufficient, and it needs no
      # `crypto` application in the release.
      {:ok, bytes} -> :erlang.md5(bytes)
      {:error, _reason} -> nil
    end
  end
end
