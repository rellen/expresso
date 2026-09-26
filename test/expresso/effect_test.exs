defmodule Expresso.EffectTest do
  use ExUnit.Case, async: true

  alias Expresso.Deck
  alias Expresso.Element.{Item, List, Part, TextBox}
  alias Expresso.Overlay.Render
  alias Expresso.Slide

  # The deck grows, slide two wipes, and one box of slide one blurs. The list
  # flies up, so its items fly up, and one item fades.
  defmodule EffectDeck do
    use Expresso

    name "effect deck"
    effect(:grow)

    slide "one" do
      text_box do
        at 2
        text_area(text: "Grows")
      end

      text_box do
        at 2
        effect(:blur)
        text_area(text: "Blurs")
      end

      list do
        reveal true
        effect(:fly_up)
        item "Flies up"

        item "Fades" do
          effect(:fade)
        end
      end
    end

    slide "two" do
      effect(:wipe)

      text_box do
        at 2
        text_area(text: "Wipes")
      end

      text_box do
        text_area(text: "Always")
      end
    end
  end

  defp document, do: EffectDeck |> Expresso.parse() |> Deck.render() |> Floki.parse_document!()

  defp effects(document, selector) do
    document |> Floki.find(selector) |> Floki.attribute("data-effect")
  end

  describe "the DSL" do
    test "writes the effect of the deck and of a slide into the metadata" do
      deck = Expresso.parse(EffectDeck)

      assert deck.metadata.effect == :grow
      assert Enum.map(deck.slides, & &1.metadata[:effect]) == [nil, :wipe]
    end

    test "gives each element the nearest effect" do
      document = document()

      assert effects(document, "#slide-1 .text-box") == ["grow", "blur"]
      assert effects(document, "#slide-1 .item") == ["fly-up"]
      assert effects(document, "#slide-2 .text-box") == ["wipe"]
    end

    test "refuses an effect that it does not know" do
      assert_raise Spark.Error.DslError, ~r/effect/, fn ->
        defmodule SpinDeck do
          use Expresso

          effect(:spin)
        end
      end
    end
  end

  describe "identify/1" do
    defp slide(elements, metadata \\ %{}) do
      %Slide{elements: elements, metadata: Map.put(metadata, :slide_number, 1)}
    end

    defp identify(slides, metadata) do
      %Deck{slides: slides} =
        Render.identify(%Deck{name: "d", metadata: metadata, slides: slides})

      slides
    end

    test "gives each element the effect of the deck, and :fade without one" do
      [%Slide{elements: [box]}] = identify([slide([%TextBox{}])], %{effect: :grow})
      assert box.effect == :grow

      [%Slide{elements: [box]}] = identify([slide([%TextBox{}])], %{})
      assert box.effect == :fade
    end

    test "prefers the slide to the deck, a parent to the slide, and the element to each" do
      list = %List{effect: :fly_left, elements: [%Item{}, %Item{effect: :blur}]}

      [%Slide{elements: [box, list]}] =
        identify([slide([%TextBox{}, list], %{effect: :wipe})], %{effect: :grow})

      assert box.effect == :wipe
      assert Enum.map(list.elements, & &1.effect) == [:fly_left, :blur]
    end
  end

  describe "attributes/1" do
    test "writes data-effect with hyphens for an element with steps" do
      assert Render.attributes(%TextBox{steps: [2], effect: :fly_up}) ==
               [{"data-on", "2"}, {"data-effect", "fly-up"}]
    end

    test "writes no data-effect for a fade or for an element without steps" do
      assert Render.attributes(%TextBox{steps: [2], effect: :fade}) == [{"data-on", "2"}]
      assert Render.attributes(%TextBox{steps: [2]}) == [{"data-on", "2"}]
      assert Render.attributes(%TextBox{effect: :grow}) == []
    end
  end

  describe "a diagram part" do
    defp svg(part) do
      Expresso.Element.Diagram.new("test/fixtures/flow.svg", [part])
      |> Expresso.Element.Diagram.get_assigns()
      |> Map.fetch!(:svg)
      |> Floki.parse_fragment!()
    end

    test "goes into a wrapper for an effect that moves or grows it" do
      [wrapper] =
        svg(%Part{id: "output", steps: [2], effect: :grow}) |> Floki.find("g.diagram-part")

      assert Floki.attribute([wrapper], "data-effect") == ["grow"]
    end

    test "keeps no wrapper for a fade, a wipe or a blur" do
      for effect <- [:fade, :wipe, :blur] do
        assert svg(%Part{id: "output", steps: [2], effect: effect})
               |> Floki.find("g.diagram-part") ==
                 []
      end
    end
  end
end
