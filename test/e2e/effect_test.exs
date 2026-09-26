defmodule Expresso.E2E.EffectTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # One slide. Each box shows at step 2 with its own effect.
  defmodule Deck do
    use Expresso

    name "effect deck"

    slide "one" do
      text_box do
        at 2
        effect(:grow)
        text_area(text: "Grow")
      end

      text_box do
        at 2
        effect(:fly_up)
        text_area(text: "Fly up")
      end

      text_box do
        at 2
        effect(:wipe)
        text_area(text: "Wipe")
      end

      text_box do
        at 2
        effect(:blur)
        text_area(text: "Blur")
      end
    end
  end

  # The computed style of each box of the present view.
  defp styles(page) do
    js(page, """
    [...document.querySelectorAll(".screen [data-effect]")].map((box) => {
      const style = getComputedStyle(box);
      return [box.dataset.effect, style.opacity, style.transform, style.clipPath, style.filter];
    })
    """)
  end

  describe "with reduced motion" do
    setup %{page: page, tmp_dir: tmp_dir} do
      %{page: open(page, render(Deck, tmp_dir))}
    end

    test "a hidden box keeps the start of its effect", %{page: page} do
      assert styles(page) == [
               ["grow", "0", "matrix(0.8, 0, 0, 0.8, 0, 0)", "none", "blur(0px) opacity(1)"],
               ["fly-up", "0", "matrix(1, 0, 0, 1, 0, 48)", "none", "blur(0px) opacity(1)"],
               [
                 "wipe",
                 "1",
                 "matrix(1, 0, 0, 1, 0, 0)",
                 "inset(-48px calc(100% + 48px) -48px -48px)",
                 "blur(0px) opacity(1)"
               ],
               ["blur", "0", "matrix(1, 0, 0, 1, 0, 0)", "none", "blur(9.6px) opacity(1)"]
             ]
    end

    test "a box is in its place at its step, and goes back after a step back", %{page: page} do
      hidden = styles(page)
      page |> press("j")

      assert styles(page) == [
               ["grow", "1", "matrix(1, 0, 0, 1, 0, 0)", "none", "blur(0px) opacity(1)"],
               ["fly-up", "1", "matrix(1, 0, 0, 1, 0, 0)", "none", "blur(0px) opacity(1)"],
               [
                 "wipe",
                 "1",
                 "matrix(1, 0, 0, 1, 0, 0)",
                 "inset(-48px calc(0% - 48px) -48px -48px)",
                 "blur(0px) opacity(1)"
               ],
               ["blur", "1", "matrix(1, 0, 0, 1, 0, 0)", "none", "blur(0px) opacity(1)"]
             ]

      page |> press("k")
      assert styles(page) == hidden
    end
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
      page = open(page, render(Deck, tmp_dir))
      js(page, "document.documentElement.style.setProperty('--dur', '2s')")
      %{slow: page}
    end

    test "a box with grow changes its size during the fade in", %{slow: page} do
      page |> press("j")

      wait_for(page, """
      (() => {
        const box = document.querySelector('.screen [data-effect="grow"]');
        const opacity = Number(getComputedStyle(box).opacity);
        return opacity > 0.3 && opacity < 0.7;
      })()
      """)

      [scale] =
        js(page, """
        [new DOMMatrix(getComputedStyle(document.querySelector('.screen [data-effect="grow"]')).transform).a]
        """)

      assert scale > 0.8 and scale < 1
    end
  end
end
