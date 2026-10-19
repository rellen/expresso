defmodule Expresso.E2E.TreeTest do
  use Expresso.E2E, async: false

  # A tree with a long detail, so the text of one box ends with an ellipsis.
  defmodule Deck do
    use Expresso

    name "tree deck"

    slide "plant" do
      tree do
        title "The plant"

        node "Ana" do
          detail "Plant manager"

          node "Ben" do
            detail "Production"
            node "Cy", detail: "Press"
            node "Di", detail: "Paint"
          end

          node "Hal", detail: "Maintenance of each machine of the two lines and of the building"
        end
      end
    end
  end

  # The rectangle of each box, the drawing and the list on the screen.
  defp geometry(page) do
    js(page, """
    (() => {
      const rect = (element) => {
        const box = element.getBoundingClientRect();
        return [box.left, box.top, box.width, box.height];
      };
      const figure = document.querySelector(".screen figure.tree");
      return {
        svg: rect(figure.querySelector("svg")),
        boxes: Array.from(figure.querySelectorAll(".tree-box"), rect),
        list: rect(figure.querySelector(".tree-list")),
        viewport: [innerWidth, innerHeight]
      };
    })()
    """)
  end

  test "each box shows in its place, in the proportions of the layout, inside the svg",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))
    %{"svg" => [left, top, width, height], "boxes" => boxes} = geometry(page)

    assert length(boxes) == 5
    assert width > 0 and height > 0

    for [x, y, w, h] <- boxes do
      assert x >= left - 1 and x + w <= left + width + 1
      assert y >= top - 1 and y + h <= top + height + 1
      # The default box is 220 by 96, and the SVG keeps the proportions.
      assert_in_delta w / h, 220 / 96, 0.05
    end

    [root, ben, cy, di, _hal] = boxes
    # The root is above Ben, and Cy and Di are side by side under Ben.
    assert Enum.at(root, 1) < Enum.at(ben, 1)
    assert Enum.at(cy, 1) == Enum.at(di, 1)
    assert Enum.at(cy, 0) < Enum.at(di, 0)
  end

  test "the tree fits the slide, and the list for a screen reader takes no space",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))

    %{"svg" => [_left, _top, width, height], "list" => list, "viewport" => [vw, vh]} =
      geometry(page)

    assert width <= vw * 0.8 + 1
    assert height <= vh * 0.72 + 1
    assert list |> Enum.drop(2) |> Enum.map(&round/1) == [1, 1]
  end

  test "a long detail ends with an ellipsis inside its box", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))

    [scroll, client, overflow] =
      js(page, """
      (() => {
        const details = document.querySelectorAll(".screen .tree-detail");
        const detail = details[details.length - 1];
        const style = getComputedStyle(detail);
        return [detail.scrollWidth, detail.clientWidth, style.textOverflow];
      })()
      """)

    assert scroll > client
    assert overflow == "ellipsis"
  end
end
