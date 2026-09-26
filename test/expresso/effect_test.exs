defmodule Expresso.EffectTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Spark.Test, only: [dsl_errors: 1]

  alias Expresso.Deck
  alias Expresso.Element.{Item, List, Part, TextArea, TextBox}
  alias Expresso.Overlay.Render
  alias Expresso.Slide

  # The deck grows, slide two wipes, and one box of slide one blurs. The list
  # flies up, so its items fly up, and one item fades.
  defmodule EffectDeck do
    use Expresso

    name "effect deck"
    effect :grow

    slide "one" do
      text_box do
        at 2
        text_area(text: "Grows")
      end

      text_box do
        at 2
        effect :blur
        text_area(text: "Blurs")
      end

      list do
        reveal true
        effect :fly_up
        item "Flies up"

        item "Fades" do
          effect :fade
        end
      end
    end

    slide "two" do
      effect :wipe

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

    test "refuses an effect without a rule in the theme or in the CSS of the deck" do
      errors =
        dsl_errors do
          defmodule Elixir.Expresso.EffectTest.SpinDeck do
            use Expresso

            effect :spin
          end
        end

      assert [{Expresso.EffectTest.SpinDeck, [error]}] = errors

      assert Exception.message(error) =~
               ~s(the effect :spin has no rule in the theme or in the CSS of the deck)

      assert Exception.message(error) =~ ~s([data-effect="spin"])
    end
  end

  describe "identify/1" do
    defp slide(elements, metadata) do
      %Slide{elements: elements, metadata: Map.put(metadata, :slide_number, 1)}
    end

    defp identify(slides, metadata) do
      %Deck{slides: slides} =
        Render.identify(%Deck{name: "d", metadata: metadata, slides: slides})

      slides
    end

    defp maybe(values), do: one_of([constant(nil), member_of(values)])

    defp timing do
      fixed_map(%{
        effect: maybe([:fade, :grow, :wipe, :fly_up]),
        speed: maybe([:fast, :slow, 450]),
        easing: maybe([:linear, :spring])
      })
    end

    defp tree(0), do: map(timing(), &struct!(TextArea, &1))

    defp tree(depth) do
      one_of([
        tree(0),
        map({timing(), list_of(tree(depth - 1), max_length: 3)}, fn {timing, children} ->
          struct!(TextBox, Map.put(timing, :elements, children))
        end),
        map({timing(), list_of(map(timing(), &struct!(Item, &1)), max_length: 3)}, fn {timing,
                                                                                       items} ->
          struct!(List, Map.put(timing, :elements, items))
        end)
      ])
    end

    defp nearest(elements, inherited) do
      Enum.map(elements, fn element ->
        values = Map.new(inherited, fn {key, value} -> {key, Map.get(element, key) || value} end)
        {values, nearest(Map.get(element, :elements) || [], values)}
      end)
    end

    defp resolved(elements) do
      Enum.map(elements, fn element ->
        values = Map.take(element, [:effect, :speed, :easing])
        {values, resolved(Map.get(element, :elements) || [])}
      end)
    end

    property "gives each element its own value, else the nearest parent, the slide, the deck" do
      check all elements <- list_of(tree(2), max_length: 4),
                slide_values <- timing(),
                deck_values <- timing() do
        [%Slide{elements: identified}] = identify([slide(elements, slide_values)], deck_values)

        deck = Map.update!(deck_values, :effect, &(&1 || :fade))
        slide = Map.new(deck, fn {key, value} -> {key, slide_values[key] || value} end)

        assert resolved(identified) == nearest(elements, slide)
      end
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
