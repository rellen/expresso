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

  defmodule NamedSlideDeck do
    use Expresso

    name("named slide deck")

    slide "intro" do
      text_box do
        text_area do
          text "an intro slide"
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

    test "numbers the slides from 1" do
      numbers = Expresso.parse(DslDeck).slides |> Enum.map(& &1.metadata.slide_number)

      assert numbers == [1, 2]
    end

    test "reads the name of a slide from the first argument" do
      assert Expresso.parse(NamedSlideDeck).slides |> Enum.map(& &1.name) == ["intro"]
    end
  end

  describe "number_slides/1" do
    test "numbers the slides of an imperative deck from 1" do
      deck =
        Expresso.Deck.new("imperative deck")
        |> Expresso.Deck.add_slide("first", %{}, [])
        |> Expresso.Deck.add_slide("second", %{}, [])

      assert Enum.map(deck.slides, & &1.metadata.slide_number) == [1, 2]
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

  describe "render/1 with a custom template" do
    defmodule CustomSlideTemplate do
      use Expresso.Template

      def render(_assigns) do
        temple do
          div class: "custom-slide" do
            "custom template"
          end
        end
      end
    end

    defmodule CustomDeckTemplate do
      use Expresso.Template.Deck

      def header(_assigns) do
        temple do
          div class: "custom-header" do
            "custom header"
          end
        end
      end

      def footer(_assigns) do
        temple do
          div class: "custom-footer" do
            "custom footer"
          end
        end
      end
    end

    test "accepts a module as the template of a slide" do
      document =
        Expresso.Deck.new("custom deck")
        |> Expresso.Deck.add_slide("first", %{template: CustomSlideTemplate}, [])
        |> Expresso.Deck.render()
        |> Floki.parse_document!()

      assert document |> Floki.find(".custom-slide") |> Floki.text() =~ "custom template"
    end

    test "accepts a module as the template of a deck" do
      document =
        Expresso.Deck.new("custom deck", %{template: CustomDeckTemplate})
        |> Expresso.Deck.add_slide("first", %{}, [])
        |> Expresso.Deck.render()
        |> Floki.parse_document!()

      assert document |> Floki.find(".custom-header") |> Floki.text() =~ "custom header"
      assert document |> Floki.find(".custom-footer") |> Floki.text() =~ "custom footer"
    end

    test "uses the built-in deck template when the metadata gives none" do
      document =
        Expresso.Deck.new("plain deck")
        |> Expresso.Deck.add_slide("first", %{}, [])
        |> Expresso.Deck.render()
        |> Floki.parse_document!()

      assert document |> Floki.find("span.header") |> Floki.text() =~ "plain deck"
    end
  end

  describe "render/1 and the doctype" do
    test "writes the doctype of HTML 5 in front of the document" do
      html =
        Expresso.Deck.new("doctype deck")
        |> Expresso.Deck.add_slide("first", %{}, [])
        |> Expresso.Deck.render()

      assert String.starts_with?(html, "<!DOCTYPE html>\n<html")
    end
  end

  describe "main/2" do
    import ExUnit.CaptureIO

    test "writes the usage text when the input path is nil" do
      output = capture_io(fn -> assert {:error, _message} = Expresso.main(nil, nil) end)

      assert output =~ "Usage: mix expresso <input> [output]"
    end

    test "gives an error when the input file is not present" do
      output =
        capture_io(fn ->
          assert {:error, _message} = Expresso.main("test/no_such_deck.exs", nil)
        end)

      assert output =~ "Couldn't find input file"
    end

    test "writes the HTML to the output path" do
      output_path = Path.join(System.tmp_dir!(), "expresso_main_test.html")
      on_exit(fn -> File.rm(output_path) end)

      assert :ok = Expresso.main("examples/dsl_deck.exs", output_path)

      html = File.read!(output_path)

      assert String.starts_with?(html, "<!DOCTYPE html>")
      assert html =~ "dsl deck"
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
