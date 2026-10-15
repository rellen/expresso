defmodule Expresso.E2E.ChartHierarchyTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # A treemap and a sunburst with two frames, and a treemap and a sunburst
  # with the effect grow at step 2.
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

    slide "sunburst grow" do
      chart :sunburst do
        title "Grow"
        categories ["Production/Press", "Production/Paint", "Support/Stops"]
        effect :grow
        at 2
        series "Hours", [60, 40, 20]
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

  describe "with motion" do
    setup %{browser: browser, tmp_dir: tmp_dir} do
      {:ok, context} =
        Browser.new_context(browser.guid,
          timeout: 10_000,
          viewport: %{width: 1280, height: 720},
          reduced_motion: "no-preference"
        )

      on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
      {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
      %{slow: page, url: render(Deck, tmp_dir)}
    end

    test "the names of a sunburst with the effect grow show after the arcs grow", %{
      slow: page,
      url: url
    } do
      page = open(page, url <> "#4")
      wait_for_position(page, "4.1")
      slow_motion(page, 10)

      # The arcs grow for 10 s, and then the names fade in.
      press(page, "j")
      pause_animations(page, "#slide-4", 3000)
      [arc | _rest] = values(page, 4, ".chart-ring", "--chart-v")
      assert arc > 0
      assert Enum.all?(values(page, 4, ".chart-label", "opacity"), &(&1 == 0))

      finish_animations(page, "#slide-4")
      assert Enum.any?(values(page, 4, ".chart-label", "opacity"), &(&1 == 1))
    end
  end
end
