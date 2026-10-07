defmodule Examples.LayoutCheck do
  use Expresso

  slide "a long line" do
    heading "A long line"

    code "elixir" do
      text ~S"""
      def total(orders), do: orders |> Enum.filter(&paid?/1) |> Enum.map(& &1.amount) |> Enum.sum()
      """
    end
  end

  slide "a long move" do
    heading "A long move"

    text_box do
      on 2, set: [x: "12rem"]
      text_area(text: "This box moves past the right edge at step 2")
    end
  end
end

Examples.LayoutCheck
