defmodule Expresso.ImperativeApiTest do
  use ExUnit.Case, async: true

  alias Expresso.Deck
  alias Expresso.Element.{TextArea, TextBox}
  alias Expresso.Slide

  # A script makes a deck with these functions, and no transformer runs for
  # them. `docs/overlays.md` gives the two input paths.

  describe "Expresso.Slide.new/3" do
    test "takes a name, metadata and elements" do
      slide = Slide.new("first", %{heading: "Hello"}, [TextBox.new("text")])

      assert slide.name == "first"
      assert slide.metadata == %{heading: "Hello"}
      assert [%TextBox{}] = slide.elements
    end

    test "gives an empty map and an empty list without them" do
      assert Slide.new("first") == %Slide{name: "first", metadata: %{}, elements: []}
    end

    test "accepts no name" do
      assert Slide.new(nil).name == nil
    end
  end

  describe "Expresso.Slide.add_element/2" do
    test "puts an element after each element of the slide" do
      slide =
        "first"
        |> Slide.new()
        |> Slide.add_element(TextBox.new("one"))
        |> Slide.add_element(TextBox.new("two"))

      assert [%TextBox{elements: [%TextArea{text: "one"}]}, %TextBox{}] = slide.elements
      assert length(slide.elements) == 2
    end
  end

  describe "Expresso.Slide.get_assigns/1" do
    test "gives the name, the metadata and the elements" do
      slide = Slide.new("first", %{heading: "Hello"}, [])

      assert Slide.get_assigns(slide) == %{
               name: "first",
               metadata: %{heading: "Hello"},
               elements: []
             }
    end
  end

  describe "Expresso.Element.TextBox.new/1" do
    test "makes a text box that holds one text area" do
      assert %TextBox{elements: [%TextArea{text: "some text"}]} = TextBox.new("some text")
    end

    test "gives the text box no overlay" do
      box = TextBox.new("some text")

      assert box.at == nil
      assert box.steps == nil
      assert box.on == []
    end
  end

  describe "Expresso.Deck.add_slide/4" do
    test "numbers each slide from 1" do
      deck =
        "d"
        |> Deck.new()
        |> Deck.add_slide("first")
        |> Deck.add_slide("second")

      assert Enum.map(deck.slides, & &1.metadata.slide_number) == [1, 2]
    end

    test "keeps the metadata of the slide" do
      deck = "d" |> Deck.new() |> Deck.add_slide("first", %{heading: "Hello"})
      [slide] = deck.slides

      assert slide.metadata.heading == "Hello"
      assert slide.metadata.slide_number == 1
    end

    test "accepts a slide with no name and no element" do
      deck = "d" |> Deck.new() |> Deck.add_slide()

      assert [%Slide{name: nil, elements: []}] = deck.slides
    end
  end

  describe "Expresso.Deck.number_slides/1" do
    test "writes a number into a slide with no metadata" do
      deck = %Deck{name: "d", metadata: %{}, slides: [%Slide{}, %Slide{}]}

      assert deck |> Deck.number_slides() |> Map.get(:slides) |> Enum.map(& &1.metadata) ==
               [%{slide_number: 1}, %{slide_number: 2}]
    end
  end

  describe "render/1 for a deck with no slide" do
    test "writes a document with no section and no handout page" do
      document = "d" |> Deck.new() |> Deck.render() |> Floki.parse_document!()

      assert Floki.find(document, "section.slide") == []
      assert Floki.find(document, ".handout-page") == []
      assert document |> Floki.find("title") |> Floki.text() == "d"
    end
  end
end
