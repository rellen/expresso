defmodule Expresso.AccessibilityOptionsTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder

  doctest Expresso.Deck, only: [lang: 1]
  doctest Expresso.Element.Video, only: [captions: 1]

  defp document(elements, opts \\ []) do
    [Builder.slide("s", elements: elements)]
    |> Builder.deck(Keyword.merge([name: "options"], opts))
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
  end

  describe "the lang option" do
    test "gives the lang attribute of the html element, and the default is en" do
      assert [] |> document() |> LazyHTML.query("html") |> LazyHTML.attribute("lang") == ["en"]

      assert [] |> document(lang: "pt-BR") |> LazyHTML.query("html") |> LazyHTML.attribute("lang") ==
               ["pt-BR"]
    end

    test "the compiler refuses a value that is not a language tag" do
      assert_raise ArgumentError, ~r/language tag/, fn ->
        Builder.deck([], name: "x", lang: "en_US")
      end
    end

    test "the DSL takes it" do
      defmodule GermanDeck do
        use Expresso

        lang "de"

        slide "start" do
          heading "Überwachung"
        end
      end

      assert {:ok, deck} = Expresso.to_deck(GermanDeck)
      assert deck.metadata.lang == "de"
    end
  end

  describe "the alt option of a diagram" do
    test "gives the diagram the role img and a name" do
      [diagram] =
        [Builder.diagram("test/fixtures/flow.svg", alt: "A request and its answer")]
        |> document()
        |> LazyHTML.query(".screen .diagram")
        |> Enum.to_list()

      assert LazyHTML.attribute(diagram, "role") == ["img"]
      assert LazyHTML.attribute(diagram, "aria-label") == ["A request and its answer"]
    end

    test "without it, the diagram has no role and no name" do
      [diagram] =
        [Builder.diagram("test/fixtures/flow.svg")]
        |> document()
        |> LazyHTML.query(".screen .diagram")
        |> Enum.to_list()

      assert LazyHTML.attribute(diagram, "role") == []
      assert LazyHTML.attribute(diagram, "aria-label") == []
    end
  end

  describe "the captions option of a video" do
    defp video(opts) do
      Builder.video(
        "test/fixtures/clip.webm",
        [title: "A clip", poster: "test/fixtures/dot.png"] ++ opts
      )
    end

    test "writes a track of captions with the file as a data URI" do
      [track] =
        [video(captions: "test/fixtures/captions.vtt")]
        |> document()
        |> LazyHTML.query(".screen video > track")
        |> Enum.to_list()

      assert LazyHTML.attribute(track, "kind") == ["captions"]
      assert LazyHTML.attribute(track, "label") == ["Captions"]
      assert LazyHTML.attribute(track, "default") != []

      [src] = LazyHTML.attribute(track, "src")
      assert "data:text/vtt;base64," <> encoded = src
      assert Base.decode64!(encoded) == File.read!("test/fixtures/captions.vtt")
    end

    test "a video without the option has no track" do
      assert [video([])] |> document() |> count(".screen video:not(:has(track))") == 1
    end

    test "the compiler refuses a file that is not a .vtt file" do
      assert_raise ArgumentError, ~r/WebVTT/, fn -> video(captions: "captions.srt") end
    end

    test "the renderer raises for a captions file that it cannot read" do
      assert_raise ArgumentError, ~r/cannot read the captions "test\/fixtures\/none.vtt"/, fn ->
        document([video(captions: "test/fixtures/none.vtt")])
      end
    end
  end
end
