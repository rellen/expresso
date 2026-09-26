defmodule Expresso.TimingTest do
  use ExUnit.Case, async: true

  alias Expresso.Deck
  alias Expresso.Element.TextBox
  alias Expresso.Overlay.Render

  # The deck is slow. Slide one springs, its first box is fast, and its second
  # box takes 450 ms. Slide two keeps the values of the deck.
  defmodule TimingDeck do
    use Expresso

    name "timing deck"
    speed(:slow)

    slide "one" do
      easing(:spring)

      text_box do
        at 2
        speed(:fast)
        text_area(text: "Fast")
      end

      text_box do
        at 2
        speed(450)
        easing(:linear)
        text_area(text: "450 ms")
      end

      text_box do
        text_area(text: "No animation")
      end
    end

    slide "two" do
      text_box do
        on 2, state: :alert
        text_area(text: "Slow")
      end
    end
  end

  defp document do
    TimingDeck |> Expresso.parse() |> Deck.render() |> Floki.parse_document!()
  end

  defp attribute(document, selector, name) do
    document |> Floki.find(selector) |> Floki.attribute(name)
  end

  describe "the DSL" do
    test "writes the speed and the easing of the deck and of a slide into the metadata" do
      deck = Expresso.parse(TimingDeck)

      assert {deck.metadata.speed, deck.metadata.easing} == {:slow, nil}

      assert Enum.map(deck.slides, &{&1.metadata[:speed], &1.metadata[:easing]}) == [
               {nil, :spring},
               {nil, nil}
             ]
    end

    test "gives each element that animates the nearest speed and easing" do
      document = document()

      assert attribute(document, "#slide-1 .text-box", "data-speed") == ["fast", "450"]
      assert attribute(document, "#slide-1 .text-box", "data-easing") == ["spring", "linear"]
      assert attribute(document, "#slide-2 .text-box", "data-speed") == ["slow"]
      assert attribute(document, "#slide-2 .text-box", "data-easing") == []
    end

    test "writes a rule for a speed in milliseconds, and none for a preset" do
      [_fonts, _theme, _highlight, generated] =
        document() |> Floki.find("head style") |> Enum.map(&Floki.text/1)

      assert generated =~ ~s([data-speed="450"] { --speed: 450ms; })
      refute generated =~ ~s([data-speed="slow"])
    end

    test "refuses a speed or an easing that it does not know" do
      for {option, value} <- [speed: :warp, speed: 0, easing: :bounce] do
        assert_raise Spark.Error.DslError, ~r/#{option}/, fn ->
          Code.eval_quoted(
            quote do
              defmodule unquote(Module.concat(__MODULE__, "Bad#{option}#{value}")) do
                use Expresso

                unquote({option, [], [value]})
              end
            end
          )
        end
      end
    end
  end

  describe "attributes/1" do
    test "writes the speed and the easing with hyphens after the other attributes" do
      box = %TextBox{steps: [2], el: "s1-e1", speed: :slow, easing: :ease_out}

      assert Render.attributes(box) == [
               {"data-on", "2"},
               {"data-el", "s1-e1"},
               {"data-speed", "slow"},
               {"data-easing", "ease-out"}
             ]
    end

    test "writes no speed and no easing for an element that does not animate" do
      assert Render.attributes(%TextBox{speed: 450, easing: :linear}) == []
    end
  end
end
