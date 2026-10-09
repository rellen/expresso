defmodule Examples.ShapeColor do
  use Expresso

  slide "the limit" do
    heading "The limit"

    table do
      header true
      row ["Machine", "Parts each hour"]
      row ["Press", "120"]
      row ["Paint", "45"]
      row ["Pack", "200"]
    end

    shape :rect do
      at from: 2
      x "24%"
      y "45.5%"
      width "53%"
      height "11%"
      on 3, set: [color: "var(--danger)"]
    end

    shape :line, from: ["46%", "54%"], to: ["51.5%", "54%"], at: [from: 3]
  end
end

Examples.ShapeColor
