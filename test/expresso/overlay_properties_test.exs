defmodule Expresso.Overlay.PropertiesTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{On, Pause, TextArea, TextBox}
  alias Expresso.Overlay.Properties
  alias Expresso.Slide
  alias Expresso.Theme
  alias Expresso.Test.Warnings

  defp warnings(elements, name \\ "s") do
    %Slide{name: name, elements: elements} |> Properties.slide() |> Warnings.texts()
  end

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
               "and neither the theme nor the CSS of the deck uses that property"
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

  describe "a set value and the syntax of the registration" do
    defp set_warnings(set), do: warnings([%TextBox{on: [%On{set: set}]}])

    test "reports a length without a unit" do
      [message] = set_warnings(x: 400)

      assert message ==
               "deck -> slide -> s: the set key `x` gives the value 400 to the custom " <>
                 "property `--x`, and the theme registers that property with the syntax " <>
                 "\"<length>\". The browser ignores the value, and the property keeps its " <>
                 "initial value. Give a length with a unit of length, such as \"400px\""
    end

    test "reports a number with a unit and an angle without a unit" do
      [scale, rotate] = set_warnings(scale: "150%", rotate: 45)

      assert scale =~ ~s(the set key `scale` gives the value "150%")
      assert scale =~ "Give a plain number without a unit, such as 1.5"
      assert rotate =~ "the set key `rotate` gives the value 45"
      assert rotate =~ ~s(Give an angle with a unit of angle, such as "45deg")
    end

    test "reports a percentage for a length, a zero angle and a length for a number" do
      assert length(set_warnings(x: "50%", rotate: 0, opacity: "1px")) == 3
    end

    test "accepts each value that the browser accepts for the syntax" do
      set = [
        x: "400px",
        y: "-1.5em",
        x: 0,
        y: "0",
        scale: 1.5,
        scale: "2",
        opacity: ".5",
        rotate: "45deg",
        rotate: "0.5turn",
        x: "1e2px"
      ]

      assert set_warnings(set) == []
    end

    test "accepts a CSS function and a CSS-wide keyword" do
      assert set_warnings(x: "calc(100% - 10px)", y: "var(--other)", scale: "inherit") == []
    end

    test "reads the registration of the CSS of the deck" do
      names = %{Theme.names() | registered: Map.put(Theme.names().registered, "x", "<number>")}
      slide = %Slide{name: "s", elements: [%TextBox{on: [%On{set: [x: "400px"]}]}]}

      assert [message] = slide |> Properties.slide(names) |> Warnings.texts()
      assert message =~ ~s(the syntax "<number>")
    end
  end

  describe "registered_state/2" do
    defp registered_state(on),
      do: Properties.registered_state(%Slide{elements: [%TextBox{on: on}]})

    test "refuses a state that takes the name of a property that the theme registers" do
      assert {:error, message} = registered_state([%On{state: :scale}])

      assert message ==
               "the state `scale` writes the custom property `--scale`, and the theme " <>
                 "registers that property with the syntax \"<number>\". The compiler " <>
                 "registers each state as a number with the initial value 0, and that " <>
                 "registration replaces the registration of the theme on each slide. " <>
                 "Give the state a different name, or use the set option"
    end

    test "refuses the states opacity and x, and reads each child element" do
      assert {:error, opacity} = registered_state([%On{set: [x: "1px"]}, %On{state: :opacity}])
      assert opacity =~ "the state `opacity`"

      box = %TextBox{elements: [%TextArea{on: [%On{state: :x}]}]}
      assert {:error, x} = Properties.registered_state(%Slide{elements: [box]})
      assert x =~ ~s(the state `x` writes the custom property `--x`, and the theme registers)
    end

    test "accepts a state that the theme does not register" do
      assert registered_state([%On{state: :alert}, %On{state: :dim}]) == :ok
      assert Properties.registered_state(%Slide{}) == :ok
    end
  end
end
