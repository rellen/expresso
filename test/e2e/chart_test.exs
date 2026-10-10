defmodule Expresso.E2E.ChartTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # A bar chart with three frames and the count option, a line chart with two
  # frames, and a bar chart with the effect grow.
  defmodule Deck do
    use Expresso

    slide "race" do
      chart :bar do
        title "Orders"
        categories ["North", "South"]
        count true
        sort true
        speed :slow

        frame "2023" do
          series "Orders", [10, 20]
        end

        frame "2024" do
          series "Orders", [30, 15.5]
        end

        frame "2025" do
          series "Orders", [40, 50]
        end
      end
    end

    slide "line" do
      chart :line do
        title "Trend"
        categories ["Q1", "Q2", "Q3"]

        frame "2023" do
          series "Sales", [1, 3, 2]
        end

        frame "2024" do
          series "Sales", [3, 1, 2]
        end
      end
    end

    slide "grow" do
      chart :bar do
        title "Grow"
        categories ["North"]
        effect :grow
        at 2
        series "Orders", [10]
      end
    end
  end

  # The value of a property on the first element of a selector in a slide.
  defp property(page, slide, selector, name) do
    js(page, """
    (() => {
      const element = document.querySelector("#slide-#{slide} .chart > svg #{selector}");
      return Number.parseFloat(getComputedStyle(element).getPropertyValue("#{name}"));
    })()
    """)
  end

  defp counts(page) do
    js(page, """
    Array.from(document.querySelectorAll("#slide-1 .chart > svg .chart-count"), (count) => count.textContent)
    """)
  end

  test "the bars take the values of each frame, and the numbers show them", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))
    first = property(page, 1, "path.chart-bar", "--chart-v")
    north = property(page, 1, "path.chart-bar", "--chart-u")
    assert counts(page) == ["10", "20"]

    press(page, "j")
    wait_for(page, ~s|document.querySelector("#slide-1 .chart-count").textContent === "30"|)
    assert property(page, 1, "path.chart-bar", "--chart-v") < first
    assert counts(page) == ["30", "15.5"]

    # South leads in 2023 and in 2025, and North leads in 2024.
    assert property(page, 1, "path.chart-bar", "--chart-u") < north
    press(page, "j")
    wait_for(page, ~s|document.querySelector("#slide-1 .chart-count").textContent === "40"|)
    assert property(page, 1, "path.chart-bar", "--chart-u") == north
    assert counts(page) == ["40", "50"]

    keys(page, ["k", "k"])
    wait_for(page, ~s|document.querySelector("#slide-1 .chart-count").textContent === "10"|)
    assert property(page, 1, "path.chart-bar", "--chart-v") == first
  end

  test "a bar with the effect grow is at the base line until its step", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir) <> "#3")
    hidden = property(page, 3, "path.chart-bar", "--chart-v")
    press(page, "j")
    shown = property(page, 3, "path.chart-bar", "--chart-v")

    # The base line is lower on the screen than the top of the bar.
    assert hidden > shown
  end

  describe "with motion" do
    # Each change lasts 2 seconds, so the test can read the page in the middle
    # of a change.
    setup %{browser: browser, tmp_dir: tmp_dir} do
      {:ok, context} =
        Browser.new_context(browser.guid,
          timeout: 10_000,
          viewport: %{width: 1280, height: 720},
          reduced_motion: "no-preference"
        )

      on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
      {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
      url = render(Deck, tmp_dir)
      page = open(page, url)
      js(page, "document.documentElement.style.setProperty('--dur', '2s')")
      %{slow: page, url: url}
    end

    test "a bar and its number pass through the values between two frames", %{slow: page} do
      first = property(page, 1, "path.chart-bar", "--chart-v")
      press(page, "j")

      wait_for(page, """
      (() => {
        const value = Number(document.querySelector("#slide-1 .chart-count").textContent);
        return value > 12 && value < 28;
      })()
      """)

      between = property(page, 1, "path.chart-bar", "--chart-v")
      assert between < first
      wait_for(page, ~s|document.querySelector("#slide-1 .chart-count").textContent === "30"|)
      assert property(page, 1, "path.chart-bar", "--chart-v") < between
    end

    test "the ends of two segments of a line stay together while they move", %{
      slow: page,
      url: url
    } do
      # The address shows the slide with a transition, and a key during that
      # transition changes the step with no motion.
      page = open(page, url <> "#2")
      Process.sleep(1000)
      js(page, "document.documentElement.style.setProperty('--dur', '2s')")
      start = property(page, 2, ".chart-dot", "--chart-v")
      press(page, "j")
      Process.sleep(600)
      between = property(page, 2, ".chart-dot", "--chart-v")
      assert between < start

      [[x1, y1], [x2, y2]] =
        js(page, """
        (() => {
          const [a, b] = document.querySelectorAll("#slide-2 .chart > svg .chart-segment");
          const end = (segment, x) => {
            const box = segment.getCTM();
            return [box.a * x + box.e, box.b * x + box.f];
          };
          return [end(a, 1), end(b, 0)];
        })()
        """)

      assert_in_delta x1, x2, 0.01
      assert_in_delta y1, y2, 0.01

      # The dot was between its two places when the test read the segments.
      Process.sleep(2000)
      assert property(page, 2, ".chart-dot", "--chart-v") < between
    end
  end
end
