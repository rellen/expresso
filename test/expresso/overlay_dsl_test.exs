defmodule Expresso.OverlayDslTest do
  use ExUnit.Case, async: true

  import Spark.Test, only: [dsl_errors: 1, dsl_warnings: 1, refute_dsl_warnings: 1]

  alias Expresso.Element.{On, TextArea, TextBox}
  alias Expresso.Overlay

  defmodule OverlayDeck do
    use Expresso

    name "overlay deck"

    slide "pipeline" do
      steps 5

      text_box do
        at from: :next
        on :next, state: :alert

        text_area do
          text "appears, then becomes prominent"
        end
      end

      pause()

      text_box do
        at 2..5
        on [from: 4], set: [x: "400px", y: "100px"]

        text_area do
          at 2..4
          text "a text area with its own steps"
        end
      end

      text_box do
        text_area do
          text "an element without a specification"
        end
      end
    end
  end

  defmodule PlainDeck do
    use Expresso

    slide do
      text_box do
        text_area do
          text "no specification"
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
      [first, second, third] = slide.elements

      assert %TextBox{at: %Overlay{pairs: [{1, :max}]}} = first
      assert %TextBox{at: %Overlay{pairs: [{2, 5}]}} = second
      assert %TextBox{at: nil} = third
    end

    test "works on a text area", %{slide: slide} do
      [_, %TextBox{elements: [area]}, _] = slide.elements

      assert %TextArea{at: %Overlay{pairs: [{2, 4}]}} = area
    end
  end

  describe "the on entity" do
    test "holds a specification and a state", %{slide: slide} do
      [%TextBox{on: [on]} | _] = slide.elements

      assert %On{at: %Overlay{pairs: [{2, 2}]}, state: :alert, set: nil} = on
    end

    test "holds a specification and custom properties", %{slide: slide} do
      [_, %TextBox{on: [on]}, _] = slide.elements

      assert %On{at: %Overlay{pairs: [{4, :max}]}, state: nil, set: [x: "400px", y: "100px"]} =
               on
    end

    test "is an empty list without an entity", %{slide: slide} do
      assert [_, _, %TextBox{on: []}] = slide.elements
    end
  end

  describe "the transformer" do
    test "gives each :next the value of the counter, and a pause increments it", %{
      slide: slide
    } do
      [%TextBox{steps: first, on: [%On{steps: on}]}, _, _] = slide.elements

      assert first == [1, 2, 3, 4, 5]
      assert on == [2]
    end

    test "expands each specification into step numbers", %{slide: slide} do
      [_, %TextBox{steps: box, on: [%On{steps: on}], elements: [%TextArea{steps: area}]}, _] =
        slide.elements

      assert box == [2, 3, 4, 5]
      assert on == [4, 5]
      assert area == [2, 3, 4]
    end

    test "keeps nil for an element without a specification", %{slide: slide} do
      assert [_, _, %TextBox{steps: nil, elements: [%TextArea{steps: nil}]}] = slide.elements
    end

    test "removes each pause from the slide", %{slide: slide} do
      assert [%TextBox{}, %TextBox{}, %TextBox{}] = slide.elements
    end

    test "writes the maximum step number into the metadata", %{slide: slide} do
      assert slide.metadata.max_step == 5
    end

    test "gives the maximum step number 1 to a slide without a specification" do
      [slide] = Expresso.parse(PlainDeck).slides

      assert slide.metadata.max_step == 1
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

    test "is the maximum, and a step above it is an error at compile time" do
      source = """
      defmodule Expresso.OverlayDslTest.TooManySteps do
        use Expresso

        slide "short" do
          steps 2

          text_box do
            at 3
          end
        end
      end
      """

      error = assert_raise Spark.Error.DslError, fn -> Code.compile_string(source) end

      assert Exception.message(error) =~ "deck -> slide -> short"
      assert Exception.message(error) =~ "the step 3 is more than the maximum step 2"
    end
  end

  describe "the verifier" do
    test "reports an on entity outside the at option" do
      errors =
        dsl_errors do
          defmodule Elixir.Expresso.OverlayDslTest.OnOutside do
            use Expresso

            slide "outside" do
              text_box do
                at 1..2
                on 3, state: :alert
              end
            end
          end
        end

      assert [{Expresso.OverlayDslTest.OnOutside, [error]}] = errors
      assert Exception.message(error) =~ "deck -> slide -> outside"
      assert Exception.message(error) =~ "the on entity has the step 3"
    end

    test "reports a child element outside its parent" do
      errors =
        dsl_errors do
          defmodule Elixir.Expresso.OverlayDslTest.ChildOutside do
            use Expresso

            slide do
              text_box do
                at 2

                text_area do
                  at 1..2
                end
              end
            end
          end
        end

      assert [{Expresso.OverlayDslTest.ChildOutside, [error]}] = errors
      assert Exception.message(error) =~ "the text_area has the step 1"
    end
  end

  describe "the auto_reveal option" do
    defmodule AutoDeck do
      use Expresso

      slide "auto" do
        auto_reveal true

        text_box do
          text_area do
            text "first"
          end
        end

        text_box do
          text_area do
            text "second"
          end
        end
      end
    end

    test "shows each element of the slide one after the other" do
      [slide] = Expresso.parse(AutoDeck).slides
      [first, second] = slide.elements

      assert first.steps == [1, 2]
      assert second.steps == [2]
      assert slide.metadata.max_step == 2
    end

    test "changes no nested element" do
      [slide] = Expresso.parse(AutoDeck).slides
      [%TextBox{elements: [area]} | _] = slide.elements

      assert area.steps == nil
    end

    test "reports a nested element with a step at which its parent does not show" do
      errors =
        dsl_errors do
          defmodule Elixir.Expresso.OverlayDslTest.AutoOutside do
            use Expresso

            slide "outside" do
              auto_reveal true

              text_box do
                text_area do
                  text "first"
                end
              end

              text_box do
                text_area do
                  at 1
                  text "second"
                end
              end
            end
          end
        end

      assert [{Expresso.OverlayDslTest.AutoOutside, [error]}] = errors

      assert Exception.message(error) =~
               "the text_area has the step 1, and the text_box does not show at that step"
    end
  end

  describe "the property verifier" do
    test "gives a warning for a set key that the theme does not use" do
      warnings =
        dsl_warnings do
          defmodule Elixir.Expresso.OverlayDslTest.UnusedKey do
            use Expresso

            slide "unused" do
              text_box do
                at 1
                on 1, set: [x: "400px", dim: 0.3]
              end
            end
          end
        end

      assert [{Expresso.OverlayDslTest.UnusedKey, [{message, _location}]}] = warnings
      assert message =~ "deck -> slide -> unused"
      assert message =~ "the set key `dim` writes the custom property `--dim`"
    end

    test "gives a warning for a state that the theme does not use" do
      warnings =
        dsl_warnings do
          defmodule Elixir.Expresso.OverlayDslTest.UnusedState do
            use Expresso

            slide "glow" do
              text_box do
                at 1
                on 1, state: :glow
              end
            end
          end
        end

      assert [{Expresso.OverlayDslTest.UnusedState, [{message, _location}]}] = warnings
      assert message =~ "the state `glow` writes the custom property `--glow`"
    end

    test "gives a warning for a state that the theme registers with a different syntax" do
      warnings =
        dsl_warnings do
          defmodule Elixir.Expresso.OverlayDslTest.StateCollision do
            use Expresso

            slide "collision" do
              text_box do
                at 1
                on 1, state: :x
              end
            end
          end
        end

      assert [{Expresso.OverlayDslTest.StateCollision, [{message, _location}]}] = warnings
      assert message =~ ~s(registers that property with the syntax "<length>")
    end

    test "gives no warning for a property of the theme" do
      refute_dsl_warnings do
        defmodule Elixir.Expresso.OverlayDslTest.UsedProperties do
          use Expresso

          slide "used" do
            text_box do
              at 1
              on 1, state: :alert
              on 1, set: [x: "400px", y: "100px"]
            end
          end
        end
      end
    end
  end

  describe "a bad specification" do
    test "is an error at compile time, with the accepted forms" do
      source = """
      defmodule Expresso.OverlayDslTest.BadDeck do
        use Expresso

        slide do
          text_box do
            at "2-4"

            text_area do
              text "x"
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
