defmodule Expresso.E2E.TimingTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # The first box is slow and springs. The second box takes 450 ms. The third
  # box keeps the time and the easing of the theme.
  defmodule Deck do
    use Expresso

    name "timing deck"

    slide "one" do
      text_box do
        at 2
        speed(:slow)
        easing(:spring)
        text_area(text: "Slow")
      end

      text_box do
        at 2
        speed(450)
        text_area(text: "450 ms")
      end

      text_box do
        at 2
        text_area(text: "Default")
      end
    end
  end

  # The duration and the easing of the fade of each box, and the duration of
  # the text area in the first box.
  defp timing(page) do
    js(page, """
    (() => {
      const boxes = [...document.querySelectorAll(".screen .text-box")];
      // The first value of a list. A comma in parentheses does not end it.
      const first = (value) => value.split(/,(?![^(]*[)])/)[0].trim();
      return {
        boxes: boxes.map((box) => {
          const style = getComputedStyle(box);
          return [first(style.transitionDuration), first(style.transitionTimingFunction)];
        }),
        child: first(getComputedStyle(boxes[0].querySelector(".text-area")).transitionDuration)
      };
    })()
    """)
  end

  defp context(browser, motion) do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: 10_000,
        viewport: %{width: 1280, height: 720},
        reduced_motion: motion
      )

    on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
    {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
    page
  end

  test "each box takes its own time and easing, and a child inherits the time", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    page = browser |> context("no-preference") |> open(render(Deck, tmp_dir))

    assert timing(page) == %{
             "boxes" => [
               ["0.6s", "cubic-bezier(0.34, 1.56, 0.64, 1)"],
               ["0.45s", "ease-in-out"],
               ["0.3s", "ease-in-out"]
             ],
             "child" => "0.6s"
           }
  end

  test "a box with a speed has no animation for a reader who asks for reduced motion", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    assert timing(page)["boxes"] |> Enum.map(&hd/1) == ["0s", "0s", "0s"]
  end
end
