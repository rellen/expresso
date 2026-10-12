defmodule Expresso.AccessibilityOptionsTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  doctest Expresso.Deck, only: [lang: 1]
  doctest Expresso.Element.Video, only: [captions: 1]

  defp document(elements, opts \\ []) do
    [Builder.slide("s", elements: elements)]
    |> Builder.deck(Keyword.merge([name: "options"], opts))
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

  describe "the lang option" do
    test "gives the lang attribute of the html element, and the default is en" do
      assert [] |> document() |> Floki.attribute("html", "lang") == ["en"]
      assert [] |> document(lang: "pt-BR") |> Floki.attribute("html", "lang") == ["pt-BR"]
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
        |> Floki.find(".screen .diagram")

      assert Floki.attribute(diagram, "role") == ["img"]
      assert Floki.attribute(diagram, "aria-label") == ["A request and its answer"]
    end

    test "without it, the diagram has no role and no name" do
      [diagram] =
        [Builder.diagram("test/fixtures/flow.svg")]
        |> document()
        |> Floki.find(".screen .diagram")

      assert Floki.attribute(diagram, "role") == []
      assert Floki.attribute(diagram, "aria-label") == []
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
        |> Floki.find(".screen video > track")

      assert Floki.attribute(track, "kind") == ["captions"]
      assert Floki.attribute(track, "label") == ["Captions"]
      assert Floki.attribute(track, "default") != []

      [src] = Floki.attribute(track, "src")
      assert "data:text/vtt;base64," <> encoded = src
      assert Base.decode64!(encoded) == File.read!("test/fixtures/captions.vtt")
    end

    test "a video without the option has no track" do
      assert [video([])] |> document() |> Floki.find("video > track") == []
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
