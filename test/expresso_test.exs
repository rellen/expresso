defmodule ExpressoTest do
  use ExUnit.Case

  doctest Expresso

  defmodule DslDeck do
    use Expresso

    name("dsl deck")

    slide do
      text_box do
        text_area do
          text "first slide"
        end
      end
    end

    slide do
      text_box do
        text_area do
          text "second slide"
        end
      end
    end
  end

  describe "parse/1" do
    test "reads the name of the deck" do
      assert Expresso.parse(DslDeck).name == "dsl deck"
    end

    test "reads each slide" do
      assert length(Expresso.parse(DslDeck).slides) == 2
    end

    test "writes a map into the metadata of the deck" do
      assert Expresso.parse(DslDeck).metadata == %{}
    end

    test "numbers the slides from 0" do
      numbers = Expresso.parse(DslDeck).slides |> Enum.map(& &1.metadata.slide_number)

      assert numbers == [0, 1]
    end
  end

  describe "to_deck/1" do
    test "accepts a deck" do
      deck = Expresso.Deck.new("a deck")

      assert Expresso.to_deck(deck) == {:ok, deck}
    end

    test "accepts a module that uses the DSL" do
      assert {:ok, %Expresso.Deck{name: "dsl deck"}} = Expresso.to_deck(DslDeck)
    end

    test "accepts the tuple of a defmodule expression" do
      value = {:module, DslDeck, <<>>, nil}

      assert {:ok, %Expresso.Deck{name: "dsl deck"}} = Expresso.to_deck(value)
    end

    test "gives an error for a module that does not use the DSL" do
      assert {:error, message} = Expresso.to_deck(Enum)
      assert message =~ "must return an Expresso.Deck struct"
    end

    test "gives an error for a different term" do
      assert {:error, _message} = Expresso.to_deck(:not_a_deck)
    end
  end

  describe "render/1 for a deck from the DSL" do
    setup do
      html = DslDeck |> Expresso.parse() |> Expresso.Deck.render()

      {:ok, html: html, document: Floki.parse_document!(html)}
    end

    test "writes the name of the deck into the title", %{document: document} do
      assert document |> Floki.find("title") |> Floki.text() |> String.trim() == "dsl deck"
    end

    test "writes one section for each slide", %{document: document} do
      assert document |> Floki.find("section.slide") |> length() == 2
    end

    test "shows the first slide only", %{document: document} do
      [first, second] = Floki.find(document, "section.slide")

      assert Floki.attribute(first, "style") |> to_string() =~ "display: flex"
      assert Floki.attribute(second, "style") |> to_string() =~ "display: none"
    end

    test "writes the text of each slide", %{html: html} do
      text = html |> Floki.parse_document!() |> Floki.find(".text-area") |> Floki.text()

      assert text =~ "first slide"
      assert text =~ "second slide"
    end

    test "writes no heading, because the DSL gives none", %{document: document} do
      assert Floki.find(document, ".slide-heading-container") == []
    end
  end

  describe "render/1 for a deck from the imperative API" do
    test "writes the heading from the metadata" do
      document =
        Expresso.Deck.new("imperative deck")
        |> Expresso.Deck.add_slide("first", %{heading: "A heading"}, [
          Expresso.Element.TextBox.new("some text")
        ])
        |> Expresso.Deck.render()
        |> Floki.parse_document!()

      heading = document |> Floki.find(".slide-heading-container h1") |> Floki.text()

      assert String.trim(heading) == "A heading"
    end
  end
end
