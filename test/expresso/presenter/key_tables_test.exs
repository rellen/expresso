defmodule Expresso.Presenter.KeyTablesTest do
  use ExUnit.Case, async: true

  alias Expresso.Presenter.{Definition, Help}
  alias Expresso.Test.KeyTables

  # `Expresso.Test.KeyTables` tells where the tables are and how to write them
  # again.
  test "the tables of keys in the README agree with the definition of the presenter" do
    text = File.read!(KeyTables.path())
    written = KeyTables.write(text)

    if System.get_env("EXPRESSO_KEYS") == "write" do
      File.write!(KeyTables.path(), written)
    end

    assert text == written, """
    A table of keys in #{KeyTables.path()} is not current. Write the tables again:

        EXPRESSO_KEYS=write mix test test/expresso/presenter/key_tables_test.exs
    """
  end

  test "the README has a table for each mode with a list of keys" do
    modes = for {mode, _rows} <- Help.rows(Definition.presenter()), do: mode

    assert Enum.sort(KeyTables.modes(File.read!(KeyTables.path()))) == Enum.sort(modes)
  end

  test "a table puts each key name in backticks, and not a label" do
    table = KeyTables.table(:present)

    assert table =~ "| `j`, `→`, `↓`, `Page Down`, `Space` | Next step"
    assert table =~ "| Click or tap a link | The slide and the step of the link |"
  end
end
