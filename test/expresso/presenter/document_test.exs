defmodule Expresso.Presenter.DocumentTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML
  import Expresso.Test.Decks

  alias Expresso.Builder
  alias Expresso.Presenter.{Definition, Help, Program}

  # A deck with three slides. Slide 2 has three steps.
  defp with_steps(counts \\ [1, 3, 2]) do
    counts
    |> Enum.with_index(1)
    |> Enum.map(fn {steps, number} ->
      elements = for step <- 1..steps//1, do: box("text #{step}")
      Builder.slide("slide #{number}", steps: steps, elements: elements)
    end)
    |> Builder.deck(name: "deck")
    |> document()
  end

  describe "the program" do
    test "is a JSON script element between the list of the steps and the bundle" do
      ids =
        with_steps() |> LazyHTML.query("body > script") |> Enum.map(&LazyHTML.attribute(&1, "id"))

      assert ids == [["expresso-deck"], ["expresso-program"], []]
    end

    test "holds the program of the deck" do
      text = with_steps() |> LazyHTML.query("script#expresso-program") |> LazyHTML.text()
      deck = Builder.deck(for(steps <- [1, 3, 2], do: Builder.slide("slide", steps: steps)))

      assert text == Program.json(Program.compile(Definition.presenter(), deck))
    end
  end

  describe "the menu" do
    test "holds a row for each slide and a row for each step, with the index and the commands of the step" do
      menu = with_steps() |> LazyHTML.query("nav#menu")

      assert count(menu, ".menu-slide") == 3

      steps = LazyHTML.query(menu, ".menu-step")

      assert Enum.map(steps, &LazyHTML.attribute(&1, "data-index")) ==
               Enum.map(0..5, &[to_string(&1)])

      for {step, index} <- Enum.with_index(steps) do
        assert LazyHTML.attribute(step, "data-commands") == [
                 index |> Program.menu() |> Program.json_commands()
               ]
      end

      firsts =
        menu
        |> LazyHTML.query(".menu-slide")
        |> Enum.flat_map(&LazyHTML.attribute(&1, "data-commands"))

      assert firsts == Enum.map([0, 1, 4], &(&1 |> Program.menu() |> Program.json_commands()))
    end

    test "a row of a slide holds a copy of its last step, and its name" do
      menu = with_steps() |> LazyHTML.query("nav#menu")

      assert menu
             |> LazyHTML.query("section.menu-thumb")
             |> Enum.flat_map(&LazyHTML.attribute(&1, "data-step")) ==
               ["1", "3", "2"]

      assert texts(menu, ".menu-name") ==
               ["slide 1", "slide 2", "slide 3"]
    end

    test "a step shows its label, and only a slide with one step and no label has data-single" do
      deck =
        Builder.deck([
          Builder.slide("one", heading: "The start", steps: 1),
          Builder.slide("two", steps: 1, labels: ["Named"]),
          Builder.slide("three", steps: 2, labels: [nil, "Second"])
        ])

      menu =
        deck |> document() |> LazyHTML.query("nav#menu")

      assert texts(menu, ".menu-name") ==
               ["The start", "two", "three"]

      assert texts(menu, ".menu-label") ==
               ["", "Named", "", "Second"]

      assert menu
             |> LazyHTML.query(".menu-step[data-single]")
             |> Enum.flat_map(&LazyHTML.attribute(&1, "data-index")) ==
               ["0"]
    end
  end

  describe "the list of keys" do
    test "is a dialog with a search field and a closed section for each mode" do
      [dialog] = with_steps() |> LazyHTML.query("dialog#help") |> Enum.to_list()

      assert LazyHTML.attribute(dialog, "open") == []
      assert LazyHTML.attribute(dialog, "closedby") == ["any"]

      assert [_field] =
               LazyHTML.query(dialog, "input#help-filter[type=text][autofocus]") |> Enum.to_list()

      sections = LazyHTML.query(dialog, "details[data-mode]")

      assert Enum.map(sections, &LazyHTML.attribute(&1, "data-mode")) ==
               [["overview"], ["menu"], ["present"], ["speaker"], ["handout"]]

      assert Enum.all?(sections, &(LazyHTML.attribute(&1, "open") == []))
    end

    test "holds the rows of Help.groups/1, with a heading for each group and the words of each row" do
      sections = LazyHTML.query(with_steps(), "details[data-mode]")
      modes = Help.groups(Definition.presenter())

      # The loop compares nothing when the document has no section.
      assert Enum.count(sections) == length(modes)

      for {section, {mode, groups}} <- Enum.zip(sections, modes) do
        assert texts(section, "summary .help-mode") == [Help.title(mode)]

        headings = for {heading, _rows} <- groups, heading, do: heading
        assert texts(section, ".help-group") == headings

        rows = Enum.flat_map(groups, fn {_heading, rows} -> rows end)

        found =
          for row <- LazyHTML.query(section, "li") do
            {LazyHTML.attribute(row, "data-words"), texts(row, "kbd"),
             row |> LazyHTML.query(".help-action") |> LazyHTML.text()}
          end

        # A row with a label shows the label and no key.
        assert found ==
                 Enum.map(rows, &{[&1.words], if(&1.label, do: [], else: &1.keys), &1.text})
      end
    end

    test "groups the rows of the present view under their headings" do
      present = Help.groups(Definition.presenter())[:present]

      assert Enum.map(present, &elem(&1, 0)) == [
               "Move through the talk",
               "Find a slide",
               "Change the screen",
               "Views and windows",
               "Mouse and touch"
             ]
    end
  end

  describe "the parts that do not change" do
    test "each page holds the index of its step, and the page of the last step of a slide is a thumbnail" do
      pages =
        for page <- LazyHTML.query(with_steps(), ".handout-page") do
          {LazyHTML.attribute(page, "data-index"),
           LazyHTML.attribute(page, "data-thumbnail") != []}
        end

      assert pages == [
               {["0"], true},
               {["1"], false},
               {["2"], false},
               {["3"], true},
               {["4"], false},
               {["5"], true}
             ]
    end

    test "the body holds the columns of the overview and the zoom of each page" do
      [style] = with_steps() |> LazyHTML.query("body") |> LazyHTML.attribute("style")

      # Three slides give two columns, and (98 - 1) / 200 is 0.485.
      assert style =~ "--overview-columns: 2;"
      assert style =~ "--overview-zoom: 0.485;"

      [style] =
        with_steps([1, 1, 1, 1, 1, 1, 1]) |> LazyHTML.query("body") |> LazyHTML.attribute("style")

      assert style =~ "--overview-columns: 3;"
      assert style =~ "--overview-zoom: 0.32;"
    end

    test "the handout view holds the four empty elements of the speaker view" do
      elements = LazyHTML.query(with_steps(), ".handout > div")

      assert Enum.map(elements, &LazyHTML.attribute(&1, "id")) ==
               [["speaker-notes"], ["speaker-position"], ["speaker-timer"], ["speaker-left"]]

      assert Enum.all?(elements, &(LazyHTML.text(&1) == ""))
    end
  end

  describe "the pages of the handout" do
    test "only the page of the last step of each slide holds the commands of a click in the overview" do
      pages =
        for page <- LazyHTML.query(with_steps(), ".handout-page") do
          {LazyHTML.attribute(page, "data-slide"), LazyHTML.attribute(page, "data-step"),
           LazyHTML.attribute(page, "data-commands")}
        end

      commands = &[Program.json_commands(Program.element(&1))]

      assert pages == [
               {["1"], ["1"], commands.(1)},
               {["2"], ["1"], []},
               {["2"], ["2"], []},
               {["2"], ["3"], commands.(2)},
               {["3"], ["1"], []},
               {["3"], ["2"], commands.(3)}
             ]
    end

    test "only the page of the last step of each slide holds the name of its slide with no step" do
      pages =
        for page <- LazyHTML.query(with_steps(), ".handout-page") do
          {LazyHTML.attribute(page, "aria-label"),
           LazyHTML.attribute(page, "data-overview-label")}
        end

      assert pages == [
               {["Slide 1 of 3: slide 1"], ["Slide 1 of 3: slide 1"]},
               {["Slide 2 of 3, step 1 of 3: slide 2"], []},
               {["Slide 2 of 3, step 2 of 3: slide 2"], []},
               {["Slide 2 of 3, step 3 of 3: slide 2"], ["Slide 2 of 3: slide 2"]},
               {["Slide 3 of 3, step 1 of 2: slide 3"], []},
               {["Slide 3 of 3, step 2 of 2: slide 3"], ["Slide 3 of 3: slide 3"]}
             ]
    end
  end
end
