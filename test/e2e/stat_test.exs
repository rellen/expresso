defmodule Expresso.E2E.StatTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # A first slide, then a stat that counts when its slide shows and a stat
  # that counts at step 2. The last slide has two numbers with more than six
  # digits, and they count at step 2.
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

    slide "big" do
      stat 1_234_567 do
        label "visitors"
        count true
        at from: 2
      end

      stat 12_345.67 do
        label "hours"
        count true
        at from: 2
      end
    end
  end

  # A stat with no steps of its own, in a column that shows at step 2.
  defmodule ColumnDeck do
    use Expresso

    slide "column" do
      columns do
        column do
          at from: 2

          stat 5000 do
            label "Orders"
            count true
          end
        end
      end
    end
  end

  @numbers "#slide-2 .stat-number"
  @big "#slide-3 .stat-number"

  defp number_js(selector, index),
    do: ~s|document.querySelectorAll("#{selector}")[#{index}]|

  defp number(text) do
    {value, ""} = text |> String.replace(",", "") |> Float.parse()
    value
  end

  # The presenter writes the number of a paused count at the next frame.
  defp paused_count(page, selector, index, last) do
    wait_for(page, """
    (() => {
      const value = Number(#{number_js(selector, index)}.textContent.replaceAll(",", ""));
      return value > 0 && value < #{last};
    })()
    """)

    js(page, """
    [#{number_js(selector, index)}.textContent,
     getComputedStyle(#{number_js(selector, index)}).getPropertyValue("--chart-n")]
    """)
  end

  test "with reduced motion, each number shows its value at once", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))
    press(page, "j")
    assert position(page) == "2.1"
    # The second stat shows at step 2, and until then it keeps the start of its count.
    wait_for_texts(page, @numbers, ["1,250", "0.0"])

    press(page, "j")
    assert position(page) == "2.2"
    wait_for_texts(page, @numbers, ["1,250", "4.2"])

    assert animations(page, @numbers) == 0
  end

  test "a stat in a container with steps keeps the start of its count until the container shows",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(ColumnDeck, tmp_dir))
    wait_for_texts(page, "#slide-1 .stat-number", ["0"])

    press(page, "j")
    assert position(page) == "1.2"
    wait_for_texts(page, "#slide-1 .stat-number", ["5,000"])
  end

  # The browser keeps six significant digits in the text of `--chart-n`.
  test "with reduced motion, a number with more than six digits shows each digit", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir) <> "#3")
    wait_for_texts(page, @big, ["0", "0.00"])

    press(page, "j")
    wait_for_texts(page, @big, ["1,234,567", "12,345.67"])
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

    test "a stat counts when its slide shows, and a stat with at counts at its step", %{
      slow: page,
      url: url
    } do
      page = page |> open(url) |> slow_motion(10)

      # A count lasts three times the duration of a change: 30 s.
      press(page, "j")
      pause_animations(page, "#slide-2", 9000)
      [orders, property] = paused_count(page, @numbers, 0, 1250)
      assert number(orders) == round(number(property))

      finish_animations(page, "#slide-2")
      wait_for_texts(page, @numbers, ["1,250", "0.0"])

      press(page, "j")
      pause_animations(page, "#slide-2", 9000)
      [revenue, property] = paused_count(page, @numbers, 1, 4.2)
      assert number(revenue) == Float.round(number(property), 1)

      finish_animations(page, "#slide-2")
      wait_for_texts(page, @numbers, ["1,250", "4.2"])
    end

    test "a stat in a column with steps counts at the step of the column", %{
      slow: page,
      tmp_dir: tmp_dir
    } do
      page = page |> open(render(ColumnDeck, tmp_dir, "column")) |> slow_motion(10)
      wait_for_texts(page, "#slide-1 .stat-number", ["0"])

      press(page, "j")
      pause_animations(page, "#slide-1", 9000)
      [orders, property] = paused_count(page, "#slide-1 .stat-number", 0, 5000)
      assert number(orders) == round(number(property))

      finish_animations(page, "#slide-1")
      wait_for_texts(page, "#slide-1 .stat-number", ["5,000"])
    end

    test "a number with more than six digits counts, and its count ends on each digit", %{
      slow: page,
      url: url
    } do
      page = page |> open(url <> "#3") |> slow_motion(10)

      press(page, "j")
      pause_animations(page, "#slide-3", 9000)
      paused_count(page, @big, 0, 1_234_567)

      finish_animations(page, "#slide-3")
      wait_for_texts(page, @big, ["1,234,567", "12,345.67"])
    end
  end
end
