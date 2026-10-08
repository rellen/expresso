defmodule Expresso.Presenter.HelpTest do
  use ExUnit.Case, async: true

  alias Expresso.Presenter.{Definition, Help}

  doctest Help

  defp binding_of(on, label \\ nil),
    do: %{on: on, commands: [], text: "A text", label: label, each: true}

  defp rows(mode), do: Definition.presenter() |> Help.rows() |> Keyword.fetch!(mode)

  describe "rows/1" do
    test "returns a list for each mode that has bindings, in the order of the definition" do
      assert Definition.presenter() |> Help.rows() |> Keyword.keys() ==
               [:overview, :menu, :present, :speaker, :handout]
    end

    test "returns a row for each binding of a mode" do
      for {mode, rows} <- Help.rows(Definition.presenter()) do
        definition = Enum.find(Definition.presenter().modes, &(&1.name == mode))
        assert length(rows) == length(definition.bindings), inspect(mode)
      end
    end

    test "lists r in the speaker view only, and s in the present view only" do
      names = fn mode -> Enum.map(rows(mode), &elem(&1, 0)) end

      assert "r" in names.(:speaker)
      refute "r" in names.(:present)
      assert "s" in names.(:present)
      refute "s" in names.(:speaker)
    end
  end

  describe "names/1" do
    test "returns the names of the keys, joined with commas" do
      assert Help.names(binding_of([{:key, "j"}, {:key, "ArrowRight"}, {:key, " "}])) ==
               "j, →, Space"
    end

    test "returns the label of a binding that has one" do
      assert Help.names(binding_of([{:key, "0"}, {:key, "1"}], "0 to 9")) == "0 to 9"
    end

    test "gives no name to an event that is not a key" do
      assert Help.names(binding_of([{:key, "k"}, {:click, :left_third}, :element])) == "k"
    end
  end
end
