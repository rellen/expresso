defmodule Expresso.E2E.StatTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # A first slide, then a stat that counts when its slide shows and a stat
  # that counts at step 2.
  defmodule Deck do
    use Expresso

    name "stat deck"

    slide "intro" do
      heading "This year"
    end

    slide "results" do
      stat 1250 do
        label "orders"
        count true
      end

      stat 4.2 do
        prefix "$"
        suffix "M"
        count true
        at from: 2
      end
    end
  end

  defp numbers(page) do
    js(page, """
    Array.from(document.querySelectorAll("#slide-2 .stat-number"), (number) => number.textContent)
    """)
  end

  test "with reduced motion, each number shows its value at once", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))
    press(page, "j")
    Process.sleep(300)
    # The second stat is hidden until step 2, and it holds the start of its count.
    assert numbers(page) == ["1,250", "0.0"]

    press(page, "j")
    Process.sleep(300)
    assert numbers(page) == ["1,250", "4.2"]
  end

  describe "with motion" do
    # Each change lasts 2 seconds, so a count lasts 6 seconds, and the test can
    # read the numbers in the middle of a count.
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

    test "a stat counts when its slide shows, and a stat with at counts at its step", %{
      slow: page,
      url: url
    } do
      page = open(page, url)
      Process.sleep(1000)
      js(page, "document.documentElement.style.setProperty('--dur', '2s')")

      press(page, "j")
      Process.sleep(1500)
      [orders, _revenue] = numbers(page)
      value = orders |> String.replace(",", "") |> String.to_integer()
      assert value > 0 and value < 1250

      Process.sleep(6000)
      assert numbers(page) == ["1,250", "0.0"]

      press(page, "j")
      Process.sleep(1500)
      [_orders, revenue] = numbers(page)
      assert String.to_float(revenue) > 0 and String.to_float(revenue) < 4.2

      Process.sleep(6000)
      assert numbers(page) == ["1,250", "4.2"]
    end
  end
end
