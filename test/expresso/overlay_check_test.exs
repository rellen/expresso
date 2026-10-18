defmodule Expresso.Overlay.CheckTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{Chart, Frame, Item, On, Pause, TextArea, TextBox}
  alias Expresso.Overlay.Check
  alias Expresso.Slide

  defp check(elements), do: Check.slide(%Slide{elements: elements})

  test "accepts an expanded slide" do
    box = %TextBox{
      steps: [1, 2, 3],
      on: [%On{steps: [2, 3]}],
      elements: [%TextArea{steps: [3]}, %TextArea{steps: nil}]
    }

    assert check([box, %TextBox{steps: nil, elements: [%TextArea{steps: [7]}]}]) == :ok
  end

  test "accepts nil elements and an empty slide" do
    assert Check.slide(%Slide{}) == :ok
    assert check([]) == :ok
  end

  test "accepts a pause at the level of the slide" do
    assert check([%Pause{}]) == :ok
  end

  test "reports a pause inside an element" do
    assert check([%TextBox{elements: [%Pause{}]}]) ==
             {:error,
              "a pause entity is inside a text_box, and a pause goes at the level of the slide"}
  end

  test "reports a step below 1" do
    assert check([%TextBox{steps: [0, 1]}]) ==
             {:error, "the text_box has the step 0, and a step is 1 or more"}

    assert check([%TextBox{on: [%On{steps: [-1]}]}]) ==
             {:error, "the on entity has the step -1, and a step is 1 or more"}
  end

  test "reports an on entity outside the at option" do
    assert check([%TextBox{steps: [1, 2], on: [%On{steps: [2, 3]}]}]) ==
             {:error, "the on entity has the step 3, and the text_box does not show at that step"}
  end

  test "reports a child outside its parent" do
    assert check([%TextBox{steps: [2], elements: [%TextArea{steps: [1, 2]}]}]) ==
             {:error, "the text_area has the step 1, and the text_box does not show at that step"}
  end

  test "reports an on entity of a child outside the child" do
    box = %TextBox{elements: [%TextArea{steps: [2], on: [%On{steps: [1]}]}]}

    assert check([box]) ==
             {:error,
              "the on entity has the step 1, and the text_area does not show at that step"}
  end

  test "reports a descendant outside its nearest ancestor with steps" do
    column = %Expresso.Element.Column{elements: [%TextArea{steps: [3]}]}
    columns = %Expresso.Element.Columns{steps: [2], elements: [column]}

    assert check([columns]) ==
             {:error, "the text_area has the step 3, and the columns does not show at that step"}
  end

  test "reports an on entity outside the nearest ancestor with steps" do
    box = %TextBox{steps: [2], elements: [%TextArea{on: [%On{steps: [3]}]}]}

    assert check([box]) ==
             {:error, "the on entity has the step 3, and the text_box does not show at that step"}
  end

  test "accepts a descendant inside its nearest ancestor with steps" do
    box = %TextBox{
      steps: [3, 4],
      elements: [%Expresso.Element.List{elements: [%Item{steps: [3, 4]}]}]
    }

    assert check([box]) == :ok
  end

  test "reports a frame of a chart that starts outside the chart" do
    frames = [%Frame{}, %Frame{steps: [3]}, %Frame{steps: [4, 5]}]

    assert check([%Chart{steps: [2, 3], timeline: frames}]) ==
             {:error,
              "a frame of the chart has the step 4, and the chart does not show at that step"}

    assert check([%Chart{steps: [2, 3, 4], timeline: frames}]) == :ok
  end
end
