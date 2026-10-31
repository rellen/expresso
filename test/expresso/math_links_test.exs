defmodule Expresso.Element.Math.LinksTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{Math, Part}
  alias Expresso.Element.Math.Links

  # The MathML of two lines as Temml writes it: each cell is in the part of its
  # line, and \from gives data-from.
  @mathml ~S(<math display="block"><mtable><mtr><mtd><mrow data-part="line1"><mi data-part="arg">g</mi><mi>x</mi></mrow></mtd></mtr><mtr><mtd><mrow data-part="line2"><mi data-from="arg">g</mi><mo>+</mo><mi data-from="arg">g</mi></mrow></mtd></mtr></mtable></math>)

  defp math(text, steps \\ [2]) do
    %Math{
      text: text,
      line_names: ["line1", "line2"],
      elements: [%Part{id: "line1"}, %Part{id: "line2", steps: steps}]
    }
  end

  test "each link gets a copy of its source in the earlier line, at the steps of its line" do
    %Math{text: text, elements: [_line1, _line2 | copies]} = Links.place(math(@mathml))

    assert Enum.map(copies, &{&1.id, &1.copy_of, &1.copy_to, &1.steps, &1.covers}) == [
             {"arg@link-1", "from-0-arg", "link-1", [2], true},
             {"arg@link-2", "from-0-arg", "link-2", [2], true}
           ]

    assert text =~ ~s(<mi class="from-0-arg" data-part="arg">g</mi>)
    assert text =~ ~s(<mi class="link-1" data-from="arg">g</mi>)
    assert text =~ ~s(<mi class="link-2" data-from="arg">g</mi>)
  end

  test "a link names the nearest earlier line with the name" do
    mathml =
      ~S(<math><mrow data-part="line1"><mi data-part="a">a</mi></mrow><mrow data-part="line2"><mi data-part="a">b</mi></mrow><mrow data-part="line3"><mi data-from="a">b</mi></mrow></math>)

    math = %Math{
      text: mathml,
      line_names: ["line1", "line2", "line3"],
      elements: [%Part{id: "line1"}, %Part{id: "line2"}, %Part{id: "line3", steps: [3]}]
    }

    %Math{text: text, elements: [_, _, _, copy]} = Links.place(math)
    assert copy.copy_of == "from-1-a"
    assert text =~ ~s(<mi class="from-1-a" data-part="a">b</mi>)
    refute text =~ "from-0-a"
  end

  test "a name that no earlier line has, and a line with no steps, stop the render" do
    assert_raise ArgumentError,
                 ~r/the link \\from\{nothing\} of a math element names no part/,
                 fn ->
                   @mathml
                   |> String.replace(~s(data-from="arg"), ~s(data-from="nothing"))
                   |> math()
                   |> Links.place()
                 end

    assert_raise ArgumentError,
                 ~r/the line "line2" of a math element has \\from, so it needs steps/,
                 fn ->
                   @mathml |> math(nil) |> Links.place()
                 end
  end

  test "a math element without links does not change" do
    math = math(String.replace(@mathml, ~s(data-from="arg"), ""))
    assert Links.place(math) == math
  end
end
