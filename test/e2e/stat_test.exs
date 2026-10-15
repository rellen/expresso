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

  # The number of a stat that counts, the stat `index` of slide 2.
  defp count_number(index), do: ~s|document.querySelectorAll("#slide-2 .stat-count")[#{index}]|

  # Wait until the presenter shows a position, such as `"2.1"`. A key press
  # returns before the presenter applies the step, and a slow computer applies
  # it later.
  defp wait_for_position(page, position) do
    wait_for(page, """
    (() => {
      const slide = [...document.querySelectorAll("section.slide")]
        .find((section) => section.style.display === "flex");
      return slide.id.replace("slide-", "") + "." + slide.dataset.step === "#{position}";
    })()
    """)
  end

  # Wait until the numbers of slide 2 show the given texts. The presenter
  # writes a number at the frame after the step.
  defp wait_for_numbers(page, texts) do
    wait_for(page, """
    JSON.stringify(Array.from(document.querySelectorAll("#slide-2 .stat-number"),
      (number) => number.textContent)) === '#{JSON.encode!(texts)}'
    """)
  end

  # The value of a computed property, such as `"625"` or `"2.1"`.
  defp number(text) do
    {value, ""} = Float.parse(text)
    value
  end

  # Pause the count of a stat at half its time, as soon as its transition
  # exists. The presenter writes the number at each frame while the number has
  # a transition, so the number then holds the middle of the count. The test
  # thus reads the middle of the count on a slow computer too.
  defp pause_count(page, index) do
    wait_for(page, """
    (() => {
      const animation = #{count_number(index)}.getAnimations()[0];
      if (animation === undefined) return false;
      animation.pause();
      animation.currentTime = animation.effect.getComputedTiming().duration / 2;
      return true;
    })()
    """)
  end

  # Wait until the paused count shows a number between its first value and its
  # last value, and return the number and the value of `--chart-n`.
  defp middle(page, index, first, last) do
    wait_for(page, """
    (() => {
      const value = Number(#{count_number(index)}.textContent.replaceAll(",", ""));
      return value > #{first} && value < #{last};
    })()
    """)

    js(page, """
    [#{count_number(index)}.textContent,
     getComputedStyle(#{count_number(index)}).getPropertyValue("--chart-n")]
    """)
  end

  # Play the paused count to its end, and wait until no transition is left.
  defp finish_count(page, index) do
    js(page, "#{count_number(index)}.getAnimations().forEach((animation) => animation.play())")
    wait_for(page, "#{count_number(index)}.getAnimations().length === 0")
  end

  test "with reduced motion, each number shows its value at once", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))
    press(page, "j")
    wait_for_position(page, "2.1")
    # The second stat is hidden until step 2, and it holds the start of its count.
    wait_for_numbers(page, ["1,250", "0.0"])

    press(page, "j")
    wait_for_position(page, "2.2")
    wait_for_numbers(page, ["1,250", "4.2"])

    # Each number took its value with no transition, so it did not count.
    assert js(page, "#{count_number(0)}.getAnimations().length") == 0
    assert js(page, "#{count_number(1)}.getAnimations().length") == 0
  end

  describe "with motion" do
    # Each change lasts 2 seconds, so a count lasts 6 seconds, and the test can
    # pause the count before its end.
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
      js(page, "document.documentElement.style.setProperty('--dur', '2s')")

      press(page, "j")
      pause_count(page, 0)
      [orders, property] = middle(page, 0, 0, 1250)
      value = orders |> String.replace(",", "") |> String.to_integer()
      assert value == round(number(property))

      finish_count(page, 0)
      wait_for_numbers(page, ["1,250", "0.0"])

      press(page, "j")
      pause_count(page, 1)
      [revenue, property] = middle(page, 1, 0, 4.2)
      assert number(revenue) == Float.round(number(property), 1)

      finish_count(page, 1)
      wait_for_numbers(page, ["1,250", "4.2"])
    end
  end
end
