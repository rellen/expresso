defmodule ExpressoTest do
  use ExUnit.Case

  import Expresso.Test.HTML

  alias Expresso.Builder

  doctest Expresso

  defp box(text), do: Builder.text_box(elements: [Builder.text_area(text: text)])

  defmodule DslDeck do
    use Expresso

    name "dsl deck"

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

  defmodule MarkupDeck do
    use Expresso

    name "markup deck"

    slide do
      text_box do
        text_area do
          text "Text accepts <b>raw HTML</b>."
        end
      end
    end
  end

  defmodule NamedSlideDeck do
    use Expresso

    name "named slide deck"

    slide "intro" do
      heading "An intro"

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

    test "writes the options of the deck into the metadata of the deck" do
      assert Expresso.parse(DslDeck).metadata == %{
               progress: true,
               handout: :all,
               print_notes: true,
               slide_numbers: false,
               duration: nil,
               transition: :fade,
               morph: :auto,
               lang: "en",
               effect: :fade,
               speed: nil,
               easing: nil,
               css: nil,
               theme: :default
             }
    end

    test "numbers the slides from 1" do
      numbers = Expresso.parse(DslDeck).slides |> Enum.map(& &1.metadata.slide_number)

      assert numbers == [1, 2]
    end

    test "reads the name of a slide from the first argument" do
      assert Expresso.parse(NamedSlideDeck).slides |> Enum.map(& &1.name) == ["intro"]
    end

    test "writes the heading option into the metadata of the slide" do
      [slide] = Expresso.parse(NamedSlideDeck).slides

      assert slide.metadata.heading == "An intro"
    end

    test "gives no heading key to a slide without the option" do
      [slide | _] = Expresso.parse(DslDeck).slides

      refute Map.has_key?(slide.metadata, :heading)
    end
  end

  describe "number_slides/1" do
    test "numbers the slides of a deck from the builder from 1" do
      deck = Builder.deck([Builder.slide("first"), Builder.slide("second")])

      assert Enum.map(deck.slides, & &1.metadata.slide_number) == [1, 2]
    end

    test "writes a number into a slide with no metadata" do
      deck = %Expresso.Deck{
        name: "d",
        metadata: %{},
        slides: [%Expresso.Slide{}, %Expresso.Slide{}]
      }

      assert deck |> Expresso.Deck.number_slides() |> Map.get(:slides) |> Enum.map(& &1.metadata) ==
               [%{slide_number: 1}, %{slide_number: 2}]
    end
  end

  describe "to_deck/1" do
    test "accepts a deck" do
      deck = Builder.deck([], name: "a deck")

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

      {:ok, html: html, document: LazyHTML.from_document(html)}
    end

    test "writes the name of the deck into the title", %{document: document} do
      assert document |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim() == "dsl deck"
    end

    test "writes one section for each slide", %{document: document} do
      assert count(document, "section.slide") == 2
    end

    test "shows the first slide only", %{document: document} do
      [first, second] = LazyHTML.query(document, "section.slide") |> Enum.to_list()

      assert LazyHTML.attribute(first, "style") |> to_string() =~ "display: flex"
      assert LazyHTML.attribute(second, "style") |> to_string() =~ "display: none"
    end

    test "writes the text of each slide", %{html: html} do
      text = html |> LazyHTML.from_document() |> LazyHTML.query(".text-area") |> LazyHTML.text()

      assert text =~ "first slide"
      assert text =~ "second slide"
    end

    test "declares the language of the document" do
      document =
        document(MarkupDeck)

      assert document |> LazyHTML.query("html") |> LazyHTML.attribute("lang") == ["en"]
    end

    test "declares the encoding in front of each other element of the head" do
      document =
        document(MarkupDeck)

      # `:first-child` counts the elements only, and not the text.
      assert [{"meta", [{"charset", "utf-8"}], _}] =
               document |> LazyHTML.query("head > :first-child") |> LazyHTML.to_tree()
    end

    test "puts the text of a text area in one block element" do
      document =
        document(MarkupDeck)

      assert [{"div", [], _}] =
               document |> screen(".text-area > *") |> LazyHTML.to_tree()

      assert texts(document, ".screen .text-area > div b") == ["raw HTML"]

      # The document holds no space in front of the period. A line break between
      # two elements becomes a space, so the renderer writes no line break.
      assert texts(document, ".screen .text-area") == ["Text accepts raw HTML."]
    end

    test "writes the script of the presenter with a closing tag on its own line" do
      # Floki writes each text node as it is. The bundle must end with a line
      # break, or the last line of the script hides the closing tag.
      html = MarkupDeck |> Expresso.parse() |> Expresso.Deck.render()

      assert html =~ "\n</script>"
    end

    test "writes no heading for a slide without the heading option", %{document: document} do
      assert count(document, "body:not(:has(.slide-heading-container))") == 1
    end

    test "writes the heading of a slide with the heading option" do
      heading =
        NamedSlideDeck
        |> document()
        |> screen(".slide-heading-container h1")
        |> LazyHTML.text()

      assert String.trim(heading) == "An intro"
    end
  end

  describe "render/1 for a deck with no name" do
    defmodule NoNameDeck do
      use Expresso

      slide do
        text_box do
          text_area do
            text "a deck with no name"
          end
        end
      end
    end

    test "gets the title Slides, and writes no header" do
      document =
        document(NoNameDeck)

      assert texts(document, "title") == ["Slides"]
      assert count(document, "body:not(:has(.screen span.header))") == 1

      assert document |> screen(".text-area") |> LazyHTML.text() =~
               "a deck with no name"
    end

    test "works through the builder" do
      document =
        [Builder.slide("first", elements: [box("text")])]
        |> Builder.deck()
        |> document()

      assert texts(document, "title") == ["Slides"]
      assert count(document, "body:not(:has(.screen span.header))") == 1
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
        [Builder.slide("first", template: CustomSlideTemplate)]
        |> Builder.deck(name: "custom deck")
        |> document()

      assert document |> LazyHTML.query(".custom-slide") |> LazyHTML.text() =~ "custom template"
    end

    test "accepts a module as the template of a deck" do
      document =
        [Builder.slide("first")]
        |> Builder.deck(name: "custom deck", template: CustomDeckTemplate)
        |> document()

      assert document |> LazyHTML.query(".custom-header") |> LazyHTML.text() =~ "custom header"
      assert document |> LazyHTML.query(".custom-footer") |> LazyHTML.text() =~ "custom footer"
    end

    test "uses the built-in deck template when the metadata gives none" do
      document =
        [Builder.slide("first")]
        |> Builder.deck(name: "plain deck")
        |> document()

      # The header holds the name of the deck and no other text.
      assert texts(document, ".screen span.header") == ["plain deck"]
    end
  end

  describe "render/1 and the doctype" do
    test "writes the doctype of HTML 5 in front of the document" do
      html =
        [Builder.slide("first")]
        |> Builder.deck(name: "doctype deck")
        |> Expresso.Deck.render()

      assert String.starts_with?(html, "<!DOCTYPE html>\n<html")
    end
  end

  describe "main/2" do
    import ExUnit.CaptureIO

    test "writes the usage text to the standard error when the input path is nil" do
      error = capture_io(:stderr, fn -> assert {:error, _message} = Expresso.main(nil, nil) end)

      assert error =~ "Usage: mix expresso <input> [output]"
    end

    test "gives an error when the input file is not present" do
      error =
        capture_io(:stderr, fn ->
          assert {:error, _message} = Expresso.main("test/no_such_deck.exs", nil)
        end)

      assert error =~ "Couldn't find input file"
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

  describe "the presenter script" do
    test "the document holds the bundle as one classic script" do
      document = document(DslDeck)

      # The other two `script` elements hold the list of the steps and the program
      # of the presenter as JSON, and a browser does not run them.
      [script] =
        document |> LazyHTML.query("script:not([type])") |> Enum.map(&LazyHTML.text/1)

      assert script =~ "keydown"
      refute script =~ "import "
      refute script =~ "export "
      refute script =~ "</script>"
    end
  end

  describe "render/1 for a deck from the builder" do
    test "writes the heading of the slide" do
      document =
        [Builder.slide("first", heading: "A heading", elements: [box("some text")])]
        |> Builder.deck(name: "builder deck")
        |> document()

      heading =
        document |> screen(".slide-heading-container h1") |> LazyHTML.text()

      assert String.trim(heading) == "A heading"
    end
  end
end
