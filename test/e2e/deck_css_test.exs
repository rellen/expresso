defmodule Expresso.E2E.DeckCssTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # The first box bounces in and shakes out. The second box drops from above.
  # The heading takes the color of the deck.
  defmodule Deck do
    use Expresso

    name "deck css deck"

    css ~S"""
    @keyframes bounce { 60% { transform: scale(1.15); } }
    @keyframes shake { 50% { transform: translateX(0.5rem); } }
    [data-effect="bounce"] { --enter-animation: bounce; --exit-animation: shake; }
    [data-effect="drop"] { --enter-y: -3rem; }
    h1 { color: rgb(201, 42, 42); }
    """

    slide "one" do
      heading "Deck CSS"

      text_box do
        at 2
        effect :bounce
        text_area(text: "Bounce")
      end

      text_box do
        at 2
        effect :drop
        text_area(text: "Drop")
      end
    end
  end

  # The animation of the first box, the offset of the second box and the color
  # of the heading.
  defp state(page) do
    js(page, """
    (() => {
      const [bounce, drop] = document.querySelectorAll(".screen .text-box");
      return [
        getComputedStyle(bounce).animationName,
        new DOMMatrix(getComputedStyle(drop).transform).f,
        getComputedStyle(document.querySelector(".screen h1")).color
      ];
    })()
    """)
  end

  test "an effect of the deck plays its keyframes and moves the box", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: 10_000,
        viewport: %{width: 1280, height: 720},
        reduced_motion: "no-preference"
      )

    on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
    {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
    page = open(page, render(Deck, tmp_dir))

    # The hidden boxes: the exit animation, and 3rem (144 px) above the place.
    assert state(page) == ["shake", -144, "rgb(201, 42, 42)"]

    # The keyframes play when the box shows.
    page |> press("j")
    wait_for(page, ~s|document.getAnimations().some((a) => a.animationName === "bounce")|)
    wait_for(page, "document.getAnimations().length === 0")
    assert state(page) == ["bounce", 0, "rgb(201, 42, 42)"]

    page |> press("k")
    wait_for(page, "document.getAnimations().length === 0")
    assert state(page) == ["shake", -144, "rgb(201, 42, 42)"]
  end
end
