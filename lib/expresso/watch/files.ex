defmodule Expresso.Watch.Files do
  @moduledoc """
  Finds a change to the files of a deck

  `Expresso.Watch` takes a snapshot of the files two times each second, and
  `changed?/2` compares it with the snapshot before it. `Expresso.DeckFile`
  gives the list of the files.

  A snapshot holds the size of each file and the time of its last change. The
  file system gives that time to the second, so a file that changed in the
  last two seconds also gets a digest of its bytes. `changed?/2` compares two
  digests only when both snapshots have one:

    * Two changes in the same second give two different digests, so the second
      change is found.
    * An old file gets no digest, so a digest that goes away is not a change.

  The section "The watch mode" of `docs/architecture.md` tells why the watch
  mode reads the file system, and not the events of the operating system.
  """

  # A file that changed in this number of seconds gets a digest of its bytes.
  @recent 2

  @typedoc "The state of each file of a deck"
  @type snapshot :: %{Path.t() => {integer(), non_neg_integer(), binary() | nil} | :missing}

  @doc """
  Tell whether a file changed from one snapshot to the next

  A file changed when:

    * its size or its time of change is different,
    * it appeared or it went away,
    * both snapshots have a digest, and the digests are different, or
    * its path is in only one of the two snapshots.
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
  Record the state of each file in a list

  A file that does not exist gets `:missing`. A new file or a removed file
  thus also gives a different snapshot.
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
