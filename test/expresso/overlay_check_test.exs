defmodule Expresso.Overlay.CheckTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{On, Pause, TextArea, TextBox}
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
             {:error,
              "the on entity has the step 3, and the at option of the text_box does not have it"}
  end

  test "reports a child outside its parent" do
    assert check([%TextBox{steps: [2], elements: [%TextArea{steps: [1, 2]}]}]) ==
             {:error,
              "the text_area has the step 1, and the at option of the text_box does not have it"}
  end

  test "reports an on entity of a child outside the child" do
    box = %TextBox{elements: [%TextArea{steps: [2], on: [%On{steps: [1]}]}]}

    assert check([box]) ==
             {:error,
              "the on entity has the step 1, and the at option of the text_area does not have it"}
  end
end
