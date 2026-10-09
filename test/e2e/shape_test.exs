defmodule Expresso.E2E.ShapeTest do
  use Expresso.E2E, async: false

  # A box at a quarter of the slide, and an arrow that shows at step 2.
  defmodule Deck do
    use Expresso

    slide "shapes" do
      steps 2

      text_box do
        text_area(text: "Text")
      end

      shape :rect do
        x "25%"
        y "25%"
        width "50%"
        height "50%"
        text "A box"
      end

      shape :arrow, from: ["10%", "10%"], to: ["20%", "20%"], at: [from: 2]
    end

    slide "next" do
      text_box do
        text_area(text: "Next")
      end
    end
  end

  # Slide 1 has an arrow that moves down and stays on the slide. Slide 2 has an
  # arrow that goes past the right edge.
  defmodule CheckDeck do
    use Expresso

    slide "inside" do
      steps 2

      shape :arrow do
        from ["5%", "30%"]
        to ["15%", "30%"]
        on 2, set: [y: "40vh"]
      end
    end

    slide "outside" do
      shape :arrow, from: ["80%", "50%"], to: ["110%", "50%"]
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  defp box(page, selector) do
    js(page, """
    (() => {
      const box = document.querySelector('#{selector}').getBoundingClientRect();
      return [box.left, box.top, box.width, box.height].map(Math.round);
    })()
    """)
  end

  test "a box takes its place and its size as parts of the slide", %{page: page} do
    assert box(page, "#slide-1 .shape-rect") == [320, 180, 640, 360]
  end

  test "an arrow shows at its step, and a click on a shape goes to the slide", %{page: page} do
    visible =
      "document.querySelector('#slide-1 .shape-line').checkVisibility({visibilityProperty: true})"

    refute js(page, visible)

    # The box takes no click, so a click on its right part shows the next step.
    page |> click(900, 360)
    wait_for(page, visible)
    assert position(page) == "1.2"
  end

  test "the layout check measures the line of an arrow, and not the box over the slide", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(CheckDeck, tmp_dir, "check") <> "?check")
    wait_for(page, "document.body.dataset.layout !== undefined")

    problems =
      js(page, ~s|[...document.querySelectorAll("#layout-check li a")].map((a) => a.textContent)|)

    assert [problem] = problems
    assert problem =~ ~r/^Slide 2, step 1: the shape .* past the right edge$/
  end
end
