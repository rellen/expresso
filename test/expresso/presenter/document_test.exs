defmodule Expresso.Presenter.DocumentTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Presenter.{Definition, Help, Program}

  # A deck with three slides. Slide 2 has three steps.
  defp document(counts \\ [1, 3, 2]) do
    counts
    |> Enum.with_index(1)
    |> Enum.map(fn {steps, number} ->
      elements = for step <- 1..steps//1, do: box("text #{step}")
      Builder.slide("slide #{number}", steps: steps, elements: elements)
    end)
    |> Builder.deck(name: "deck")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

  defp box(text), do: Builder.text_box(elements: [Builder.text_area(text: text)])

  describe "the program" do
    test "is a JSON script element between the list of the steps and the bundle" do
      ids = document() |> Floki.find("body > script") |> Enum.map(&Floki.attribute(&1, "id"))

      assert ids == [["expresso-deck"], ["expresso-program"], []]
    end

    test "holds the program of the deck" do
      text = document() |> Floki.find("script#expresso-program") |> Floki.text(js: true)
      deck = Builder.deck(for(steps <- [1, 3, 2], do: Builder.slide("slide", steps: steps)))

      assert text == Program.json(Program.compile(Definition.presenter(), deck))
    end
  end

  describe "the menu" do
    test "holds a row for each slide and a row for each step, with the index and the commands of the step" do
      menu = document() |> Floki.find("nav#menu")

      assert menu |> Floki.find(".menu-slide") |> length() == 3

      steps = Floki.find(menu, ".menu-step")

      assert Enum.map(steps, &Floki.attribute(&1, "data-index")) ==
               Enum.map(0..5, &[to_string(&1)])

      for {step, index} <- Enum.with_index(steps) do
        assert Floki.attribute(step, "data-commands") == [
                 index |> Program.menu() |> Program.json_commands()
               ]
      end

      firsts =
        menu |> Floki.find(".menu-slide") |> Enum.flat_map(&Floki.attribute(&1, "data-commands"))

      assert firsts == Enum.map([0, 1, 4], &(&1 |> Program.menu() |> Program.json_commands()))
    end

    test "a row of a slide holds a copy of its last step, and its name" do
      menu = document() |> Floki.find("nav#menu")

      assert menu
             |> Floki.find("section.menu-thumb")
             |> Enum.flat_map(&Floki.attribute(&1, "data-step")) ==
               ["1", "3", "2"]

      assert menu |> Floki.find(".menu-name") |> Enum.map(&Floki.text/1) ==
               ["slide 1", "slide 2", "slide 3"]
    end

    test "a step shows its label, and only a slide with one step and no label has data-single" do
      deck =
        Builder.deck([
          Builder.slide("one", heading: "The start", steps: 1),
          Builder.slide("two", steps: 1, labels: ["Named"]),
          Builder.slide("three", steps: 2, labels: [nil, "Second"])
        ])

      menu = deck |> Expresso.Deck.render() |> Floki.parse_document!() |> Floki.find("nav#menu")

      assert menu |> Floki.find(".menu-name") |> Enum.map(&Floki.text/1) ==
               ["The start", "two", "three"]

      assert menu |> Floki.find(".menu-label") |> Enum.map(&Floki.text/1) ==
               ["", "Named", "", "Second"]

      assert menu
             |> Floki.find(".menu-step[data-single]")
             |> Enum.flat_map(&Floki.attribute(&1, "data-index")) ==
               ["0"]
    end
  end

  describe "the list of keys" do
    test "holds a hidden list for each mode, with the rows of Help.rows/1" do
      lists = Floki.find(document(), "#help > div")

      assert Enum.map(lists, &Floki.attribute(&1, "data-mode")) ==
               [["overview"], ["menu"], ["present"], ["speaker"], ["handout"]]

      assert Enum.all?(lists, &(Floki.attribute(&1, "hidden") != []))

      for {list, {_mode, rows}} <- Enum.zip(lists, Help.rows(Definition.presenter())) do
        found =
          for row <- Floki.find(list, "div > div") do
            {row |> Floki.find("kbd") |> Floki.text(), row |> Floki.find("span") |> Floki.text()}
          end

        assert found == rows
      end
    end
  end

  describe "the parts that do not change" do
    test "each page holds the index of its step, and the page of the last step of a slide is a thumbnail" do
      pages =
        for page <- Floki.find(document(), ".handout-page") do
          {Floki.attribute(page, "data-index"), Floki.attribute(page, "data-thumbnail") != []}
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
      [style] = document() |> Floki.find("body") |> Floki.attribute("style")

      # Three slides give two columns, and (98 - 1) / 200 is 0.485.
      assert style =~ "--overview-columns: 2;"
      assert style =~ "--overview-zoom: 0.485;"

      [style] = document([1, 1, 1, 1, 1, 1, 1]) |> Floki.find("body") |> Floki.attribute("style")
      assert style =~ "--overview-columns: 3;"
      assert style =~ "--overview-zoom: 0.32;"
    end

    test "the handout view holds the four empty elements of the speaker view" do
      elements = Floki.find(document(), ".handout > div")

      assert Enum.map(elements, &Floki.attribute(&1, "id")) ==
               [["speaker-notes"], ["speaker-position"], ["speaker-timer"], ["speaker-left"]]

      assert Enum.all?(elements, &(Floki.text(&1) == ""))
    end
  end

  describe "the pages of the handout" do
    test "only the page of the last step of each slide holds the commands of a click in the overview" do
      pages =
        for page <- Floki.find(document(), ".handout-page") do
          {Floki.attribute(page, "data-slide"), Floki.attribute(page, "data-step"),
           Floki.attribute(page, "data-commands")}
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
  end
end
