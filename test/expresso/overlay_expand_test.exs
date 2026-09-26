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

  describe "the auto_reveal option" do
    defp auto(elements), do: expand(elements, auto_reveal: true)

    test "gives an implicit specification to each element of the slide" do
      slide = auto([%TextBox{}, %TextBox{}, %TextBox{}])

      assert Enum.map(slide.elements, & &1.steps) == [[1, 2, 3], [2, 3], [3]]
      assert slide.metadata.max_step == 3
    end

    test "changes no nested element" do
      [box] = auto([%TextBox{elements: [%TextArea{}, %TextArea{}]}]).elements

      assert box.steps == [1]
      assert Enum.map(box.elements, & &1.steps) == [nil, nil]
    end

    test "keeps the specification of an element that has one" do
      slide = auto([%TextBox{at: spec(3)}, %TextBox{}])

      assert Enum.map(slide.elements, & &1.steps) == [[3], [1, 2, 3]]
    end

    test "reads the at option before the on entity of the same element" do
      [box] = auto([%TextBox{on: [%On{at: spec(:next)}]}]).elements

      assert box.steps == [1, 2]
      assert Enum.map(box.on, & &1.steps) == [[2]]
    end

    test "gives a pause one step, and the pause reveals no element" do
      slide = auto([%TextBox{}, %Pause{}, %TextBox{}])

      assert Enum.map(slide.elements, & &1.steps) == [[1, 2, 3], [3]]
      assert slide.metadata.max_step == 3
    end

    test "does nothing when the option is false or nil" do
      assert [%TextBox{steps: nil}] = expand([%TextBox{}], auto_reveal: false).elements
      assert [%TextBox{steps: nil}] = expand([%TextBox{}]).elements
    end

    test "leaves a pause of the slide in the counter only" do
      slide = auto([%Pause{}, %TextBox{}])

      assert Enum.map(slide.elements, & &1.steps) == [[2]]
    end
  end

  describe "the reveal option" do
    defp list(fields), do: struct!(Expresso.Element.List, [reveal: true] ++ fields)
    defp item, do: %Expresso.Element.Item{}

    test "gives an implicit specification to each child without an at option" do
      [list] = expand([list(elements: [item(), item(), %{item() | at: spec(1)}])]).elements

      assert Enum.map(list.elements, & &1.steps) == [[1, 2], [2], [1]]
      assert list.steps == nil
    end

    test "reads the counter of the slide after the at option and the on entities" do
      list = list(at: spec(from: :next), on: [%On{at: spec(:next)}], elements: [item(), item()])
      [list, box] = expand([list, %TextBox{at: spec(:next)}]).elements

      assert list.steps == [1, 2, 3, 4, 5]
      assert Enum.map(list.on, & &1.steps) == [[2]]
      assert Enum.map(list.elements, & &1.steps) == [[3, 4, 5], [4, 5]]
      assert box.steps == [5]
    end

    test "starts a local counter at the first step of an absolute at option" do
      list = list(at: spec([3, from: 5]), elements: [item(), item(), item()])
      [list, box] = expand([list, %TextBox{at: spec(:next)}]).elements

      assert Enum.map(list.elements, & &1.steps) == [[3, 4, 5], [4, 5], [5]]
      assert box.steps == [1]
      assert list.steps == [3, 5]
    end

    test "keeps the first child without a specification with the header option" do
      rows = [%Expresso.Element.Row{}, %Expresso.Element.Row{}, %Expresso.Element.Row{}]
      table = struct!(Expresso.Element.Table, reveal: true, header: true, elements: rows)
      [table] = expand([table]).elements

      assert Enum.map(table.elements, & &1.steps) == [nil, [1, 2], [2]]
    end

    test "does nothing without the option" do
      [list] = expand([list(reveal: false, elements: [item(), item()])]).elements

      assert Enum.map(list.elements, & &1.steps) == [nil, nil]
    end
  end

  describe "the dim option" do
    defp dim_list(elements),
      do: struct!(Expresso.Element.List, reveal: true, dim: true, elements: elements)

    defp dims(element),
      do: Enum.map(element.elements, &for(%On{state: :dim} = on <- &1.on, do: on.steps))

    test "dims each child from the first step of the next child" do
      [list] = expand([dim_list([item(), item(), item()])]).elements

      assert dims(list) == [[[2, 3]], [[3]], []]
      assert [%On{at: at} | _] = hd(list.elements).on
      assert at == spec([2, 3])
    end

    test "adds the state after the on entities of the child" do
      child = %{item() | on: [%On{at: spec(1), set: [x: "1px"]}]}
      [list] = expand([dim_list([child, item()])]).elements

      assert [%On{set: [x: "1px"], steps: [1]}, %On{state: :dim, steps: [2]}] =
               hd(list.elements).on
    end

    test "dims a child only at its own steps" do
      [list] =
        expand([
          dim_list([%{item() | at: spec(1..2)}, %{item() | at: spec(2)}, %{item() | at: spec(3)}])
        ]).elements

      assert dims(list) == [[[2]], [], []]
    end

    test "does not dim or count a child without steps" do
      rows = [%Expresso.Element.Row{}, %Expresso.Element.Row{}, %Expresso.Element.Row{}]

      table =
        struct!(Expresso.Element.Table, reveal: true, header: true, dim: true, elements: rows)

      [table] = expand([table]).elements

      assert dims(table) == [[], [[2]], []]
    end

    test "dims each group of lines of a code element" do
      code = Expresso.Element.Code.new("a\nb\nc\n", reveal: [1, 2..3], dim: true)
      [code] = expand([code]).elements

      assert dims(code) == [[[2]], []]
    end

    test "does nothing without the option" do
      [list] = expand([list(elements: [item(), item()])]).elements

      assert dims(list) == [[], []]
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
