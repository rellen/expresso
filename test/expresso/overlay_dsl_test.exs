defmodule Expresso.OverlayDslTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{On, Pause, TextArea, TextBox}
  alias Expresso.Overlay

  defmodule OverlayDeck do
    use Expresso

    name("overlay deck")

    slide "pipeline" do
      steps(5)

      text_box do
        at(from: :next)
        on(:next, state: :alert)

        text_area do
          text("appears, then becomes prominent")
        end
      end

      pause()

      text_box do
        at(3)
        on([from: 4], set: [x: "400px", dim: 0.3])

        text_area do
          at(2..4)
          text("a text area with its own steps")
        end
      end

      text_box do
        text_area do
          text("an element without a specification")
        end
      end
    end
  end

  setup do
    [slide] = Expresso.parse(OverlayDeck).slides
    {:ok, slide: slide}
  end

  describe "the at option" do
    test "goes into the element as a specification", %{slide: slide} do
      [first, _pause, second, third] = slide.elements

      assert %TextBox{at: %Overlay{pairs: [{:next, :max}]}} = first
      assert %TextBox{at: %Overlay{pairs: [{3, 3}]}} = second
      assert %TextBox{at: nil} = third
    end

    test "works on a text area", %{slide: slide} do
      [_, _, %TextBox{elements: [area]}, _] = slide.elements

      assert %TextArea{at: %Overlay{pairs: [{2, 4}]}} = area
    end
  end

  describe "the on entity" do
    test "holds a specification and a state", %{slide: slide} do
      [%TextBox{on: [on]} | _] = slide.elements

      assert %On{at: %Overlay{pairs: [{:next, :next}]}, state: :alert, set: nil} = on
    end

    test "holds a specification and custom properties", %{slide: slide} do
      [_, _, %TextBox{on: [on]}, _] = slide.elements

      assert %On{at: %Overlay{pairs: [{4, :max}]}, state: nil, set: [x: "400px", dim: 0.3]} =
               on
    end

    test "is an empty list without an entity", %{slide: slide} do
      assert [_, _, _, %TextBox{on: []}] = slide.elements
    end
  end

  describe "the pause entity" do
    test "is an element of the slide, in document order", %{slide: slide} do
      assert [%TextBox{}, %Pause{}, %TextBox{}, %TextBox{}] = slide.elements
    end

    test "does not stop the render" do
      html = OverlayDeck |> Expresso.parse() |> Expresso.Deck.render()

      assert html =~ "appears, then becomes prominent"
      assert html =~ "an element without a specification"
    end
  end

  describe "the steps option" do
    test "goes into the slide", %{slide: slide} do
      assert slide.steps == 5
    end
  end

  describe "a bad specification" do
    test "is an error at compile time, with the accepted forms" do
      source = """
      defmodule Expresso.OverlayDslTest.BadDeck do
        use Expresso

        slide do
          text_box do
            at("2-4")

            text_area do
              text("x")
            end
          end
        end
      end
      """

      error = assert_raise Spark.Error.DslError, fn -> Code.compile_string(source) end

      assert Exception.message(error) =~ "is not an overlay specification"
    end
  end
end
