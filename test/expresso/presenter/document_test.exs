defmodule Expresso.Presenter.DocumentTest do
  use ExUnit.Case, async: true

  alias Expresso.Presenter.{Definition, Help, Program}

  # A deck with three slides. Slide 2 has three steps.
  defp document(counts \\ [1, 3, 2]) do
    counts
    |> Enum.with_index(1)
    |> Enum.reduce(Expresso.Deck.new("deck"), fn {steps, number}, deck ->
      elements = for step <- 1..steps//1, do: Expresso.Element.TextBox.new("text #{step}")
      Expresso.Deck.add_slide(deck, "slide #{number}", %{max_step: steps}, elements)
    end)
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

  describe "the program" do
    test "is a JSON script element between the list of the steps and the bundle" do
      ids = document() |> Floki.find("body > script") |> Enum.map(&Floki.attribute(&1, "id"))

      assert ids == [["expresso-deck"], ["expresso-program"], []]
    end

    test "holds the program of the deck" do
      text = document() |> Floki.find("script#expresso-program") |> Floki.text(js: true)
      deck = Expresso.Deck.new("deck")

      deck =
        Enum.reduce([1, 3, 2], deck, fn steps, deck ->
          Expresso.Deck.add_slide(deck, "slide", %{max_step: steps}, [])
        end)

      assert text == Program.json(Program.compile(Definition.presenter(), deck))
    end
  end

  describe "the list of keys" do
    test "holds a hidden list for each mode, with the rows of Help.rows/1" do
      lists = Floki.find(document(), "#help > div")

      assert Enum.map(lists, &Floki.attribute(&1, "data-mode")) ==
               [["overview"], ["present"], ["speaker"], ["handout"]]

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
