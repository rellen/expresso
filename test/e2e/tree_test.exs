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

  # A tree with a color for each branch, a role on one node, an image, an
  # icon, and a slide with a legend.
  defmodule ColorDeck do
    use Expresso

    name "tree colors"
    root "examples"

    slide "branches" do
      tree do
        title "The plant"
        color :branch

        node "Ana" do
          image "logo.png"
          node "Ben", icon: "factory", fields: [team: "42 people"]
          node "Hal", color: :danger
        end
      end
    end

    slide "sites" do
      tree do
        title "The sites"
        color {:field, "site"}

        node "HQ" do
          fields site: "Berlin"
          node "Sales", fields: [site: "Lyon"]
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

  # The color of a custom property of the root, as the browser gives it.
  defp property(page, name) do
    js(page, """
    (() => {
      const probe = document.createElement("span");
      probe.style.color = "var(#{name})";
      document.body.append(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    })()
    """)
  end

  test "a box of a branch has a border in the color of the palette, and a role comes first",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(ColorDeck, tmp_dir))

    borders =
      js(page, """
      Array.from(
        document.querySelectorAll(".screen .tree-box"),
        (box) => [box.querySelector(".tree-label").textContent, getComputedStyle(box).borderTopColor]
      ).slice(0, 3)
      """)

    assert borders == [
             ["Ana", property(page, "--muted")],
             ["Ben", property(page, "--chart-1")],
             ["Hal", property(page, "--danger")]
           ]
  end

  test "the image is a circle, and the icon has the color of its box",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(ColorDeck, tmp_dir))

    [[width, height, radius, loaded], icon] =
      js(page, """
      (() => {
        const image = document.querySelector(".screen .tree-image");
        const style = getComputedStyle(image);
        const box = image.getBoundingClientRect();
        const icon = document.querySelector(".screen .tree-icon");
        return [
          [box.width, box.height, style.borderRadius, image.naturalWidth > 0],
          getComputedStyle(icon).color
        ];
      })()
      """)

    assert width > 0 and abs(width - height) < 1
    assert radius == "50%"
    assert loaded
    assert icon == property(page, "--chart-1")
  end

  test "the legend shows each value with the color of its boxes",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(ColorDeck, tmp_dir))
    press(page, "j")

    legend =
      js(page, """
      (() => {
        const figure = document.querySelectorAll(".screen figure.tree")[1];
        const svg = figure.querySelector("svg").getBoundingClientRect();
        return Array.from(figure.querySelectorAll(".tree-legend li"), (item) => {
          const box = item.getBoundingClientRect();
          return [
            item.textContent.trim(),
            getComputedStyle(item.querySelector(".tree-swatch")).backgroundColor,
            box.height > 0 && box.bottom <= svg.bottom + 1
          ];
        });
      })()
      """)

    assert legend == [
             ["Berlin", property(page, "--chart-1"), true],
             ["Lyon", property(page, "--chart-2"), true]
           ]
  end
end
