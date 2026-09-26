defmodule Expresso.E2E.TransitionTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # The deck fades. Slide two slides in, slide three has no transition, and
  # slide four fades.
  defmodule Deck do
    use Expresso

    name "transition deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      transition :slide
      steps 2

      text_box do
        text_area(text: "Two")
      end
    end

    slide "three" do
      transition :none

      text_box do
        text_area(text: "Three")
      end
    end

    slide "four" do
      text_box do
        text_area(text: "Four")
      end
    end
  end

  # A page in a context that does not ask for reduced motion. The transition
  # lasts 2 seconds, so a test can read its animations.
  setup %{browser: browser, tmp_dir: tmp_dir} do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: 10_000,
        viewport: %{width: 1280, height: 720},
        reduced_motion: "no-preference"
      )

    on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
    {:ok, moving} = BrowserContext.new_page(context.guid, timeout: 10_000)
    moving = open(moving, render(Deck, tmp_dir))
    js(moving, "document.documentElement.style.setProperty('--transition-dur', '2s')")
    %{moving: moving}
  end

  # The animations of the view transition that run. The overlays and the
  # progress bar have CSS transitions of their own, and they are not in it.
  @view_transition """
  document.getAnimations().filter((animation) =>
    animation.effect?.pseudoElement?.startsWith("::view-transition"))
  """

  defp animations(page) do
    js(page, "(#{@view_transition}).map((animation) => animation.animationName).sort()")
  end

  defp started(page), do: wait_for(page, "(#{@view_transition}).length > 0")
  defp settle(page), do: wait_for(page, "(#{@view_transition}).length === 0")

  test "a move to the next slide runs the transition of that slide", %{moving: page} do
    page |> press("j")

    started(page)
    assert js(page, "document.documentElement.dataset.transition") == "slide"
    assert js(page, "document.documentElement.dataset.direction") == "forward"
    assert "expresso-in-right" in animations(page)
    assert "expresso-out-left" in animations(page)

    settle(page)
    assert position(page) == "2.1"
  end

  test "a move back plays the same kind in reverse", %{moving: page} do
    page |> press("j") |> started() |> settle() |> press("k")

    started(page)
    assert js(page, "document.documentElement.dataset.direction") == "back"
    assert "expresso-in-left" in animations(page)

    settle(page)
    assert position(page) == "1.1"
  end

  test "a slide without the option uses the fade of the deck", %{moving: page} do
    page |> navigate("#3.1") |> press("j")

    started(page)
    assert js(page, "document.documentElement.dataset.transition") == "fade"
    refute Enum.any?(animations(page), &String.starts_with?(&1, "expresso-"))

    settle(page)
    assert position(page) == "4.1"
  end

  test "a change of the step and the kind none run no transition", %{moving: page} do
    page |> press("j") |> started() |> settle() |> press("j")
    assert animations(page) == []
    assert position(page) == "2.2"

    page |> press("j")
    assert animations(page) == []
    assert position(page) == "3.1"
  end

  test "a reader who asks for reduced motion gets no transition", %{page: page, tmp_dir: tmp_dir} do
    page |> open(render(Deck, tmp_dir)) |> press("j")

    assert animations(page) == []
    assert position(page) == "2.1"
  end

  defp navigate(page, hash) do
    js(page, "location.hash = '#{hash}'")
    settle(page)
  end
end
