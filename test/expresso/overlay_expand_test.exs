defmodule Expresso.Overlay.ExpandTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{On, Pause, TextArea, TextBox}
  alias Expresso.Overlay
  alias Expresso.Overlay.Expand
  alias Expresso.Slide

  defp spec(term) do
    {:ok, spec} = Overlay.new(term)
    spec
  end

  defp expand(elements, fields \\ []) do
    {:ok, slide} = Expand.slide(struct!(Slide, [elements: elements] ++ fields))
    slide
  end

  describe "the counter" do
    test "starts at 1, and each :next of one specification takes its value" do
      [box] = expand([%TextBox{at: spec([:next, from: :next])}]).elements

      assert box.at == spec([1, from: 1])
      assert box.steps == [1]
    end

    test "increments after a specification with :next" do
      [first, second] = expand([%TextBox{at: spec(:next)}, %TextBox{at: spec(:next)}]).elements

      assert first.steps == [1]
      assert second.steps == [2]
    end

    test "does not increment after a specification without :next" do
      [_, second] = expand([%TextBox{at: spec(4)}, %TextBox{at: spec(:next)}]).elements

      assert second.steps == [1]
    end

    test "increments at a pause" do
      [box] = expand([%Pause{}, %Pause{}, %TextBox{at: spec(:next)}]).elements

      assert box.steps == [3]
    end

    test "reads the at option, then each on entity, then each child" do
      box = %TextBox{
        at: spec(from: :next),
        on: [%On{at: spec(:next)}, %On{at: spec(:next)}],
        elements: [%TextArea{at: spec(:next)}]
      }

      [box] = expand([box]).elements

      assert box.steps == [1, 2, 3, 4]
      assert Enum.map(box.on, & &1.steps) == [[2], [3]]
      assert [%TextArea{steps: [4]}] = box.elements
    end

    test "leaves a pause inside an element in place" do
      [box] = expand([%TextBox{elements: [%Pause{}, %TextArea{at: spec(:next)}]}]).elements

      assert [%Pause{}, %TextArea{steps: [1]}] = box.elements
    end
  end

  describe "the maximum step number" do
    test "is the largest step number of the specifications" do
      slide = expand([%TextBox{at: spec(2), on: [%On{at: spec(6)}]}])

      assert slide.metadata.max_step == 6
    end

    test "is 1 for a slide without a specification" do
      assert expand([%TextBox{}]).metadata.max_step == 1
      assert expand([]).metadata.max_step == 1
    end

    test "comes from a :next as well" do
      assert expand([%Pause{}, %TextBox{at: spec(:next)}]).metadata.max_step == 2
    end

    test "is the steps option of the slide when the slide declares it" do
      slide = expand([%TextBox{at: spec(2)}], steps: 4)

      assert slide.metadata.max_step == 4
    end

    test "goes into the metadata of the slide, and keeps the other keys" do
      slide = expand([], metadata: %{heading: "x"})

      assert slide.metadata == %{heading: "x", max_step: 1}
    end

    test "ends an open specification" do
      [box] = expand([%TextBox{at: spec(from: 2)}], steps: 4).elements

      assert box.steps == [2, 3, 4]
    end
  end

  describe "the result" do
    test "removes each pause at the level of the slide" do
      slide = expand([%Pause{}, %TextBox{}, %Pause{}])

      assert [%TextBox{}] = slide.elements
    end

    test "keeps nil for an element without an at option" do
      [box] = expand([%TextBox{elements: [%TextArea{}]}]).elements

      assert %TextBox{steps: nil, elements: [%TextArea{steps: nil}]} = box
    end

    test "accepts nil elements" do
      assert {:ok, %Slide{elements: []}} = Expand.slide(%Slide{})
    end

    test "is an error for a step above the steps option" do
      slide = %Slide{name: "s", steps: 2, elements: [%TextBox{at: spec(3)}]}

      assert Expand.slide(slide) == {:error, "the step 3 is more than the maximum step 2"}
    end

    test "is an error for an on entity above the steps option" do
      slide = %Slide{steps: 2, elements: [%TextBox{on: [%On{at: spec(1..3)}]}]}

      assert {:error, "the step 3 is more than the maximum step 2"} = Expand.slide(slide)
    end
  end
end
