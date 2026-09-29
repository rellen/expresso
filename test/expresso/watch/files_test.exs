defmodule Expresso.Watch.FilesTest do
  use ExUnit.Case, async: true

  alias Expresso.Watch.Files

  @moduletag :tmp_dir

  describe "snapshot/1" do
    test "gives a recent file its size, its time of change and a digest", %{tmp_dir: dir} do
      path = Path.join(dir, "deck.exs")
      File.write!(path, "one")

      assert %{^path => {_time, 3, digest}} = Files.snapshot([path])
      refute digest == nil
    end

    test "gives :missing for a file that does not exist", %{tmp_dir: dir} do
      path = Path.join(dir, "new.css")
      assert Files.snapshot([path]) == %{path => :missing}
    end
  end

  describe "changed?/2" do
    test "finds no change in a file that did not change", %{tmp_dir: dir} do
      path = Path.join(dir, "deck.exs")
      File.write!(path, "one")
      snapshot = Files.snapshot([path])

      refute Files.changed?(snapshot, Files.snapshot([path]))
    end

    test "finds a change of the bytes in the same second", %{tmp_dir: dir} do
      path = Path.join(dir, "deck.exs")
      File.write!(path, "one")
      before = Files.snapshot([path])

      %File.Stat{mtime: mtime} = File.stat!(path, time: :posix)
      File.write!(path, "two")
      File.touch!(path, mtime)

      assert Files.changed?(before, Files.snapshot([path]))
    end

    test "finds no change when a digest goes away, and a change of the time", %{tmp_dir: dir} do
      path = Path.join(dir, "deck.exs")
      File.write!(path, "one")
      recent = Files.snapshot([path])
      {time, size, _digest} = recent[path]

      # An old file gets no digest.
      refute Files.changed?(recent, %{path => {time, size, nil}})
      assert Files.changed?(recent, %{path => {time + 1, size, nil}})
    end

    test "finds a file that appears, and a path in only one snapshot", %{tmp_dir: dir} do
      path = Path.join(dir, "new.css")
      missing = Files.snapshot([path])

      File.write!(path, "a {}")
      assert Files.changed?(missing, Files.snapshot([path]))
      assert Files.changed?(%{}, missing)
    end
  end
end
