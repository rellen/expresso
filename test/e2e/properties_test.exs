defmodule Expresso.E2E.PropertiesTest do
  use Expresso.E2E, async: false

  # One slide. The box grows, turns, changes color and fades at step 2. The
  # items of the list show at step 1 and at step 2, and the first item dims at
  # step 2.
  defmodule Deck do
    use Expresso

    name "properties deck"

    slide "one" do
      text_box do
        on 2, set: [scale: 1.5, rotate: "90deg", color: "rgb(200, 0, 0)", opacity: 0.5]
        text_area(text: "A box")
      end

      list do
        reveal true
        dim true
        item "first"
        item "second"
      end
    end

    # The row and the part move and get the outline at step 2.
    slide "two" do
      table do
        row ["a", "b"]

        row ["c", "d"] do
          on 2, state: :alert, set: [x: "40px"]
        end
      end

      diagram "test/fixtures/flow.svg" do
        part "output" do
          on 2, state: :alert, set: [scale: 2]
        end
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  # The computed style of the box, of its text area and of the items. The
  # context asks for reduced motion, so each change is instant.
  defp styles(page) do
    js(page, """
    (() => {
      const box = document.querySelector(".screen .text-box");
      const items = [...document.querySelectorAll(".screen .item")];
      return {
        transform: getComputedStyle(box).transform,
        filter: getComputedStyle(box).filter,
        color: getComputedStyle(box.querySelector(".text-area")).color,
        items: items.map((item) => getComputedStyle(item).filter)
      };
    })()
    """)
  end

  # The last item has no later item, so it has no on entity and no filter.
  test "the box keeps its style before the step, and the first item shows in full", %{
    page: page
  } do
    assert styles(page) == %{
             "transform" => "matrix(1, 0, 0, 1, 0, 0)",
             "filter" => "blur(0px) opacity(1)",
             "color" => "rgb(0, 0, 0)",
             "items" => ["blur(0px) opacity(1)", "none"]
           }
  end

  test "the set keys change the box at the step", %{page: page} do
    page |> press("j")
    style = styles(page)

    # A turn of 90 degrees and a scale of 1.5 give this matrix.
    assert style["transform"] == "matrix(0, 1.5, -1.5, 0, 0, 0)"
    assert style["filter"] == "blur(0px) opacity(0.5)"
    assert style["color"] == "rgb(200, 0, 0)"
  end

  test "an item dims when a later item shows, and shows in full again after a step back", %{
    page: page
  } do
    page |> press("j")
    assert styles(page)["items"] == ["blur(0px) opacity(0.4)", "none"]

    page |> press("k")
    assert styles(page)["items"] == ["blur(0px) opacity(1)", "none"]
  end

  # The transform and the outline of the row and of the wrapper of the part,
  # and the box of the part on the screen.
  defp row_and_part(page) do
    js(page, """
    (() => {
      const row = document.querySelector(".screen .row[data-el]");
      const part = document.querySelector(".screen .diagram-part");
      const box = part.getBoundingClientRect();
      return {
        row: [getComputedStyle(row).transform, getComputedStyle(row).outlineWidth],
        part: [getComputedStyle(part).transform, getComputedStyle(part).outlineWidth],
        width: Math.round(box.width)
      };
    })()
    """)
  end

  test "a table row and a diagram part move, change size and get the outline", %{page: page} do
    page |> press("End")
    start = row_and_part(page)

    assert start["row"] == ["matrix(1, 0, 0, 1, 0, 0)", "0px"]
    assert start["part"] == ["matrix(1, 0, 0, 1, 0, 0)", "0px"]

    page |> press("j")
    moved = row_and_part(page)

    assert moved["row"] == ["matrix(1, 0, 0, 1, 40, 0)", "4px"]
    assert moved["part"] == ["matrix(2, 0, 0, 2, 0, 0)", "2px"]

    # The part grows around its center, and its box on the screen doubles.
    assert_in_delta moved["width"], start["width"] * 2, 2
  end
end
