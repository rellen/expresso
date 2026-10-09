defmodule Examples.Shape do
  use Expresso

  slide "the result" do
    heading "The result"

    code "elixir" do
      text ~S"""
      def total(orders) do
        orders
        |> Enum.map(& &1.price)
        |> Enum.sum()
      end
      """
    end

    shape :ellipse, x: "33%", y: "54.5%", width: "37%", height: "14%", at: [from: 2]

    shape :arrow, from: ["82%", "31%"], to: ["70%", "56%"], at: [from: 2]

    shape :rect do
      at from: 2
      x "66%"
      y "18%"
      width "30%"
      height "12%"
      text "One pass for each order"
      fill true
    end
  end
end

Examples.Shape
