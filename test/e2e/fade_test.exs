defmodule Expresso.E2E.FadeTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # One slide. The box and its text area show from step 2.
  defmodule Deck do
    use Expresso

    name "fade deck"

    slide "one" do
      text_box do
        text_area(text: "Always")
      end

      text_box do
        at from: 2
        text_area(text: "From step 2")
      end
    end
  end

  # A page in a context that does not ask for reduced motion. Each fade lasts
  # 2 seconds, so the test can read the page in the middle of a fade.
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

  # The opacity of the box, and the visibility of the text area in it.
  defp box(page) do
    js(page, """
    (() => {
      const box = document.querySelector('.screen [data-on~="2"]');
      return {
        opacity: Number(getComputedStyle(box).opacity),
        text: getComputedStyle(box.querySelector(".text-area")).visibility
      };
    })()
    """)
  end

  defp middle(page) do
    wait_for(page, """
    (() => {
      const opacity = Number(getComputedStyle(document.querySelector('.screen [data-on~="2"]')).opacity);
      return opacity > 0.3 && opacity < 0.7;
    })()
    """)
  end

  test "the text of an element shows during the fade in of the element", %{slow: page} do
    page |> press("j") |> middle()

    assert box(page)["text"] == "visible"
  end

  test "the text of an element shows during the fade out, and hides after it", %{slow: page} do
    page |> press("j")
    wait_for(page, "document.getAnimations().length === 0")

    page |> press("k") |> middle()
    assert box(page)["text"] == "visible"

    wait_for(page, "document.getAnimations().length === 0")
    assert box(page) == %{"opacity" => 0, "text" => "hidden"}
  end
end
