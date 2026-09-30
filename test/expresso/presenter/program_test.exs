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

      assert mode(program([1]), :speaker).keys["r"] == [
               {:clear, :digits},
               {:builtin, :reset_timer}
             ]
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

  describe "compile/2 and the deck" do
    test "takes the first value of progress from the deck" do
      shown = Expresso.Deck.new("deck")
      hidden = Expresso.Deck.new("deck", %{progress: false})
      bare = %Expresso.Deck{name: "deck", metadata: nil, slides: []}

      assert Program.compile(Definition.presenter(), shown).state.progress
      refute Program.compile(Definition.presenter(), hidden).state.progress
      assert Program.compile(Definition.presenter(), bare).state.progress
    end
  end

  describe "json/1" do
    test "writes the projections of the definition" do
      project = [1, 2] |> program() |> Program.json() |> JSON.decode!() |> Map.fetch!("project")

      assert ["view", "data-view", false] in project["attributes"]
      assert ["blank", "data-blank", true] in project["attributes"]
      assert ["digits", "data-digits", false] in project["attributes"]
      assert project["properties"] == [["--fraction", "fraction"]]

      assert [
               "data-speaker",
               ".handout-page",
               "index",
               [["current", "index", 0], ["next", "index", 1]]
             ] in project["marks"]
    end

    test "writes the first state and each mode in the order of the interpreter" do
      data = [1, 2] |> program() |> Program.json() |> JSON.decode!()

      assert data["state"]["view"] == "present"
      assert data["state"]["selected"] == 1

      assert Enum.map(data["modes"], & &1["name"]) ==
               ~w(blank help overview present speaker handout)
    end

    test "puts the events with the same commands in one pair" do
      data = [1, 2] |> program() |> Program.json() |> JSON.decode!()
      present = Enum.find(data["modes"], &(&1["name"] == "present"))

      assert [" ", "ArrowDown", "ArrowRight", "PageDown", "j"] in Enum.map(present["keys"], &hd/1)
      assert [["right"], [["clear", "digits"], ["step", 1]]] in present["click"]
      assert present["other"] == [["clear", "digits"]]
      assert present["any"] == nil
    end

    test "writes each command as an array with the name first" do
      data = [1, 2] |> program() |> Program.json() |> JSON.decode!()
      present = Enum.find(data["modes"], &(&1["name"] == "present"))
      commands = Map.new(present["keys"], fn [[key | _keys], commands] -> {key, commands} end)

      assert commands["o"] == [
               ["clear", "digits"],
               ["set", "overview", true],
               ["assign", "selected", ["entry", "slide"]]
             ]

      # `End` goes to step 1 of the last slide, which has the index 1.
      assert commands["End"] == [["clear", "digits"], ["goto", 1]]
      assert commands["s"] == [["clear", "digits"], ["builtin", "open_speaker"]]
    end

    test "writes null for the last step of a deck with no slide" do
      data = [] |> program() |> Program.json() |> JSON.decode!()
      present = Enum.find(data["modes"], &(&1["name"] == "present"))
      commands = Map.new(present["keys"], fn [[key | _keys], commands] -> {key, commands} end)

      assert commands["End"] == [["clear", "digits"], ["goto", nil]]
    end

    test "returns the same text for each render, and the text has no <" do
      text = [1, 3, 2] |> program() |> Program.json()

      assert text == [1, 3, 2] |> program() |> Program.json()
      refute text =~ "<"
    end
  end

  describe "element/1" do
    test "goes to step 1 of the slide, and closes the overview" do
      assert Program.element(4) == [{:goto_slide, 4}, {:set, :overview, false}]
    end
  end
end
