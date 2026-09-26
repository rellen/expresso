defmodule Expresso.Overlay.PropertiesTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{On, Pause, TextArea, TextBox}
  alias Expresso.Overlay.Properties
  alias Expresso.Slide

  defp warnings(elements, name \\ "s") do
    %Slide{name: name, elements: elements} |> Properties.slide() |> Enum.map(&message/1)
  end

  defp message({text, _anno}), do: text
  defp message(text), do: text

  test "gives no warning for a property of the theme" do
    on = [%On{state: :alert}, %On{set: [x: "1px", y: "2px"]}]

    assert warnings([%TextBox{on: on}]) == []
  end

  test "gives no warning for a slide with no on entity" do
    assert warnings([%TextBox{elements: [%TextArea{}]}, %Pause{}]) == []
    assert Properties.slide(%Slide{}) == []
  end

  test "reports a set key that the theme does not use" do
    [message] = warnings([%TextBox{on: [%On{set: [blur: 0.3]}]}])

    assert message ==
             "deck -> slide -> s: the set key `blur` writes the custom property `--blur`, " <>
               "and the theme does not use that property"
  end

  test "reports a state that the theme does not use" do
    [message] = warnings([%TextBox{on: [%On{state: :glow}]}])

    assert message =~ "the state `glow` writes the custom property `--glow`"
  end

  test "reports a state that takes the name of a property of the theme" do
    [message] = warnings([%TextBox{on: [%On{state: :dur}]}])

    assert message ==
             "deck -> slide -> s: the state `dur` writes the custom property `--dur` as a " <>
               "number, and the theme gives that property a value of a different type"
  end

  test "reports a state that the theme registers with a different syntax" do
    [message] = warnings([%TextBox{on: [%On{state: :x}]}])

    assert message ==
             "deck -> slide -> s: the state `x` writes the custom property `--x` as a number, " <>
               "and the theme registers that property with the syntax \"<length>\""
  end

  test "reads each on entity of each element, and each child element" do
    box = %TextBox{
      on: [%On{state: :glow}, %On{set: [blur: 1]}],
      elements: [%TextArea{on: [%On{set: [blur: 1]}]}]
    }

    assert length(warnings([box])) == 3
  end

  test "writes the path of a slide without a name" do
    [message] = warnings([%TextBox{on: [%On{state: :glow}]}], nil)

    assert message =~ "deck -> slide: "
  end
end
