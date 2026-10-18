defmodule Expresso.E2E.SvgCopyTest do
  use Expresso.E2E, async: false

  # Each slide holds a file with ids or with a style element. The document
  # holds each slide in the present view, on each page of the handout view and
  # in the menu, so each copy must keep its own ids and its own rules.
  defmodule Deck do
    use Expresso

    name "svg copies"
    icons fig: "test/fixtures/copies/figma.svg"

    slide "red" do
      diagram "test/fixtures/copies/red.svg"
      icon "fig"
    end

    slide "blue" do
      diagram "test/fixtures/copies/blue.svg"
      icon "fig"
    end

    slide "mermaid" do
      diagram "test/fixtures/copies/mermaid.svg"
    end

    slide "tspan" do
      diagram "test/fixtures/copies/tspan.svg" do
        part "v" do
          on 2, state: :dim
        end
      end
    end
  end

  # The file has the ids `g1` and `g1-2`. In this deck, a copy of the file
  # gets the number 2, and the id `g1` of that copy becomes `g1-2`.
  defmodule GradientDeck do
    use Expresso

    name "gradients"

    slide "gradients" do
      diagram "test/fixtures/copies/gradients.svg"
    end
  end

  # The value of a function of each copy of an element, for each slide.
  defp each_copy(page, selector, function) do
    js(page, """
    Array.from(document.querySelectorAll(#{inspect(selector)})).map((element) => (#{function})(element))
    """)
  end

  test "the style of a file applies only to the copies of that file", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    fills =
      each_copy(page, ".diagram rect[id^='box-']", """
      (rect) => [rect.closest("svg").querySelector("style").textContent.includes("FF0000"),
                 getComputedStyle(rect).fill]
      """)

    assert length(fills) > 2

    for [red?, fill] <- fills do
      assert fill == if(red?, do: "rgb(255, 0, 0)", else: "rgb(0, 0, 255)")
    end
  end

  test "an #id selector of a style reaches the numbered root of each copy", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    fills = each_copy(page, ".diagram .node rect", "(rect) => getComputedStyle(rect).fill")

    assert length(fills) > 1
    assert Enum.all?(fills, &(&1 == "rgb(236, 236, 255)"))
  end

  test "each gradient reference goes to its own gradient in the same copy", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(GradientDeck, tmp_dir))

    stops =
      each_copy(page, ".diagram rect[id^='blue-']", """
      (rect) => {
        const id = rect.getAttribute("fill").slice(5, -1);
        const gradient = rect.closest("svg").querySelector("[id='" + id + "']");
        return gradient && gradient.querySelector("stop").getAttribute("stop-color");
      }
      """)

    assert length(stops) > 1
    assert Enum.all?(stops, &(&1 == "#0000ff"))
  end

  test "a part in a tspan keeps the class of the file at each step", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = page |> open(render(Deck, tmp_dir)) |> keys(["j", "j", "j", "j"])

    [[class, weight]] =
      js(page, """
      Array.from(document.querySelectorAll(".screen tspan")).filter((t) => t.checkVisibility())
        .map((t) => [t.getAttribute("class"), getComputedStyle(t).fontWeight])
      """)

    assert class == "diagram-part hl"
    assert weight == "700"
  end

  test "an icon of the deck keeps its clip on the second slide", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = page |> open(render(Deck, tmp_dir)) |> press("j")

    # The clip is a circle in the middle of the box. A point near a corner of
    # the box is outside the circle, so the rect is not at that point.
    [center, corner] =
      js(page, """
      (() => {
        const svg = Array.from(document.querySelectorAll(".screen svg.icon-svg"))
          .find((svg) => svg.checkVisibility());
        const box = svg.getBoundingClientRect();
        const center = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
        const corner = document.elementFromPoint(box.left + 2, box.top + 2);
        return [center.tagName, corner.tagName];
      })()
      """)

    assert center == "rect"
    assert corner != "rect"
  end
end
