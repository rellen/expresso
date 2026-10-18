defmodule Expresso.PrivateDirTest do
  use ExUnit.Case, async: true

  alias Expresso.PrivateDir

  @moduletag :tmp_dir

  # Wait until the directory goes away, for up to five seconds.
  defp wait_for_removal(path, tries \\ 100) do
    cond do
      not File.exists?(path) -> :ok
      tries == 0 -> flunk("#{path} is still there")
      true -> wait_again(path, tries)
    end
  end

  defp wait_again(path, tries) do
    Process.sleep(50)
    wait_for_removal(path, tries - 1)
  end

  describe "create!/3" do
    test "makes a new directory with the mode 0700 and a random name", %{tmp_dir: dir} do
      first = PrivateDir.create!("watch", dir)
      second = PrivateDir.create!("watch", dir)

      assert first != second
      assert Path.basename(first) =~ ~r/\Aexpresso-watch-[a-z2-7]{26}\z/
      assert %File.Stat{type: :directory, mode: mode} = File.stat!(first)
      assert Bitwise.band(mode, 0o777) == 0o700
    end

    test "does not accept a directory or a link that is already there", %{tmp_dir: dir} do
      other = Path.join(dir, "other")
      File.mkdir!(other)
      File.mkdir!(Path.join(dir, "expresso-check-a"))
      File.ln_s!(other, Path.join(dir, "expresso-check-b"))
      names = :counters.new(1, [])

      random = fn ->
        :counters.add(names, 1, 1)
        Enum.at(["a", "b", "c"], :counters.get(names, 1) - 1)
      end

      assert PrivateDir.create!("check", dir, random) == Path.join(dir, "expresso-check-c")
      assert File.ls!(other) == []
    end

    test "raises after ten names that are already there", %{tmp_dir: dir} do
      File.mkdir!(Path.join(dir, "expresso-check-a"))

      assert_raise File.Error, ~r/file already exists/, fn ->
        PrivateDir.create!("check", dir, fn -> "a" end)
      end
    end
  end

  describe "open!/1 and close/1" do
    test "close/1 removes the directory with its files" do
      private_dir = PrivateDir.open!("test")
      File.write!(Path.join(private_dir.path, "index.html"), "the deck")

      assert PrivateDir.close(private_dir) == :ok
      refute File.exists?(private_dir.path)
    end

    test "the directory goes away when the process that owns it stops" do
      test = self()

      owner =
        spawn(fn ->
          private_dir = PrivateDir.open!("test")
          File.write!(Path.join(private_dir.path, "index.html"), "the deck")
          send(test, {:path, private_dir.path})
          Process.sleep(:infinity)
        end)

      assert_receive {:path, path}, 5_000
      assert File.exists?(path)

      Process.exit(owner, :kill)
      wait_for_removal(path)
    end
  end
end
