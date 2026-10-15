defmodule Expresso.Test.DeckFilesTest do
  use ExUnit.Case, async: true

  alias Expresso.Test.DeckFiles

  @moduletag :tmp_dir

  # A file that sends `:evaluated` to the test process at each evaluation, and
  # returns `:value`.
  defp file(tmp_dir) do
    path = Path.join(tmp_dir, "deck.exs")
    pid = self() |> :erlang.pid_to_list() |> List.to_string()
    File.write!(path, "send(:erlang.list_to_pid(~c\"#{pid}\"), :evaluated)\n:value\n")
    path
  end

  test "evaluates a file one time, and returns its value each time", %{tmp_dir: tmp_dir} do
    path = file(tmp_dir)

    assert DeckFiles.eval(path) == :value
    assert DeckFiles.eval(path) == :value
    assert_received :evaluated
    refute_received :evaluated
  end

  test "evaluates a file one time when two processes ask for it at the same time", %{
    tmp_dir: tmp_dir
  } do
    path = file(tmp_dir)

    assert [:value, :value] =
             [fn -> DeckFiles.eval(path) end, fn -> DeckFiles.eval(path) end]
             |> Enum.map(&Task.async/1)
             |> Task.await_many()

    assert_received :evaluated
    refute_received :evaluated
  end
end
