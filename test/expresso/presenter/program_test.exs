defmodule Expresso.Presenter.ProgramTest do
  use ExUnit.Case, async: true

  import Expresso.Test.Presenter, only: [program: 1]

  alias Expresso.Presenter.{Definition, Program}

  doctest Program

  defp mode(program, name), do: Enum.find(program.modes, &(&1.name == name))

  describe "compile/2" do
    test "changes each symbol into a number for the deck" do
      # A deck of seven slides has three columns. Step 1 of the last slide has the index 8.
      program = program([1, 1, 3, 1, 1, 1, 2])
      overview = mode(program, :overview)
      present = mode(program, :present)

      assert overview.keys["ArrowDown"] == [{:select_by, 3}]
      assert overview.keys["ArrowUp"] == [{:select_by, -3}]
      assert overview.keys["End"] == [{:select, 7}]
      assert present.keys["End"] == [{:clear, :digits}, {:goto, 8}]
    end

    test "a deck with no slide has no last slide" do
      assert mode(program([]), :present).keys["End"] == [{:clear, :digits}, {:goto, nil}]
    end

    test "puts the each commands of a mode in front of each binding, except a binding with each: false" do
      present = mode(program([1]), :present)

      assert present.keys["j"] == [{:clear, :digits}, {:step, 1}]
      assert present.keys["5"] == [{:append, :digits}]
      assert present.keys["Enter"] == [:go_typed]
      assert present.click[:left_third] == [{:clear, :digits}, {:step, -1}]
      assert present.swipe[:left] == [{:clear, :digits}, {:step, 1}]
      assert present.other == [{:clear, :digits}]
      assert mode(program([1]), :speaker).keys["r"] == [{:builtin, :reset_timer}]
    end

    test "puts each binding of a key in its own mode only" do
      program = program([1])

      assert mode(program, :present).keys["s"] == [{:clear, :digits}, {:builtin, :open_speaker}]
      refute Map.has_key?(mode(program, :speaker).keys, "s")
      refute Map.has_key?(mode(program, :present).keys, "r")
      assert mode(program, :handout).keys["p"] == [{:clear, :digits}, {:set, :view, :present}]
      assert mode(program, :present).keys["p"] == [{:clear, :digits}, {:set, :view, :handout}]
    end

    test "raises an error for a key with two bindings in one mode" do
      definition = Definition.presenter()
      [blank | modes] = definition.modes
      twice = %{on: [{:key, "j"}], commands: [], text: "Again", label: nil, each: true}
      broken = %{blank | bindings: [twice, twice], any: nil}

      assert_raise ArgumentError, ~r/two bindings for key "j"/, fn ->
        Program.compile(%{definition | modes: [broken | modes]}, Expresso.Deck.new("deck"))
      end
    end
  end

  describe "element/1" do
    test "goes to step 1 of the slide, and closes the overview" do
      assert Program.element(4) == [{:goto_slide, 4}, {:set, :overview, false}]
    end
  end
end
