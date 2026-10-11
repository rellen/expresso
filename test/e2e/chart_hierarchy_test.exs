defmodule Expresso.E2E.ChartHierarchyTest do
  use Expresso.E2E, async: false

  # A treemap and a sunburst with two frames, and a treemap with the effect
  # grow at step 2.
  defmodule Deck do
    use Expresso

    slide "treemap" do
      chart :treemap do
        title "Hours"
        categories ["Production/Press", "Production/Paint", "Support/Stops"]

        frame "2024" do
          series "Hours", [60, 40, 20]
        end

        frame "2025" do
          series "Hours", [20, 40, 60]
        end
      end
    end

    slide "sunburst" do
      chart :sunburst do
        title "Hours"
        categories ["Production/Press", "Production/Paint", "Support/Stops"]

        frame "2024" do
          series "Hours", [60, 40, 20]
        end

        frame "2025" do
          series "Hours", [20, 40, 60]
        end
      end
    end

    slide "grow" do
      chart :treemap do
        title "Grow"
        categories ["A", "B"]
        effect :grow
        at 2
        series "S", [3, 1]
      end
    end
  end

  # The values of a property on each element of a selector in a slide.
  defp values(page, slide, selector, name) do
    js(page, """
    Array.from(
      document.querySelectorAll("#slide-#{slide} .chart > svg #{selector}"),
      (element) => Number.parseFloat(getComputedStyle(element).getPropertyValue("#{name}"))
    )
    """)
  end

  defp area(page, slide) do
    for [w, h] <-
          Enum.zip_with(
            values(page, slide, ".chart-tile", "--chart-w"),
            values(page, slide, ".chart-tile", "--chart-h"),
            &[&1, &2]
          ),
        do: w * h
  end

  test "the boxes of a treemap take the areas of each frame", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))

    # The tiles have the order of the first frame: Press, Paint, Stops.
    [press, paint, stops] = area(page, 1)
    assert press > paint and paint > stops

    press(page, "j")
    [press, paint, stops] = area(page, 1)
    assert stops > paint and paint > press
  end

  test "the arcs of a sunburst take the angles of each frame", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir) <> "#2")

    # The arcs are the groups, then their parts: Production, Press, Paint,
    # Support, Stops.
    [production | _rest] = values(page, 2, ".chart-ring", "--chart-v")
    press(page, "j")
    [later | _rest] = values(page, 2, ".chart-ring", "--chart-v")

    assert later < production
  end

  test "a treemap with the effect grow has boxes of no size until its step", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir) <> "#3")
    assert Enum.all?(area(page, 3), &(&1 == 0))

    press(page, "j")
    assert Enum.all?(area(page, 3), &(&1 > 0))
  end
end
