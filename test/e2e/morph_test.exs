defmodule Expresso.E2E.MorphTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # Slides 1 and 2 share a heading, a stat and a key. Slide 3 asks for the keys
  # only, and slide 4 asks for no morph. Slides 5 and 6 hold two codes. Slides
  # 7 and 8 hold two videos with the same poster, and slides 8 and 9 hold the
  # same video with two posters.
  defmodule Deck do
    use Expresso

    name "morph deck"

    slide "first" do
      heading "Coffee"

      stat 42 do
        label "cups"
      end

      icon "coffee" do
        morph "brand"
      end
    end

    slide "second" do
      heading "Coffee"

      text_area do
        text "Expresso"
        morph "brand"
      end

      stat 42 do
        label "cups"
      end
    end

    slide "third" do
      morph :named
      heading "Coffee"

      text_area do
        text "Expresso"
        morph "brand"
      end
    end

    slide "fourth" do
      morph :off
      heading "Coffee"

      text_area do
        text "Expresso"
        morph "brand"
      end
    end

    slide "fifth" do
      code "elixir" do
        text "x = 1"
      end
    end

    slide "sixth" do
      code "elixir" do
        text "x = 1 + 2"
      end
    end

    slide "seventh" do
      video "examples/animations/clip.webm" do
        title "A clip"
        poster "examples/animations/clip.png"
      end
    end

    slide "eighth" do
      video "examples/line4/run.webm" do
        title "A run"
        poster "examples/animations/clip.png"
      end
    end

    slide "ninth" do
      video "examples/line4/run.webm" do
        title "A run"
        poster "examples/animations/demo.png"
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

  @view_transition """
  document.getAnimations().filter((animation) =>
    animation.effect?.pseudoElement?.startsWith("::view-transition"))
  """

  # The names of the morph groups of the view transition that runs.
  defp groups(page) do
    js(page, """
    [...new Set((#{@view_transition})
      .map((animation) => animation.effect.pseudoElement)
      .filter((name) => name.startsWith("::view-transition-group(expresso-morph-")))]
      .sort()
    """)
  end

  defp started(page), do: wait_for(page, "(#{@view_transition}).length > 0")

  # Wait for the end of the view transition. A transition names its elements
  # before its animations start, and it removes the names at its end. Thus a
  # transition with no animation and with names has not started yet.
  defp settle(page) do
    wait_for(
      page,
      "(#{@view_transition}).length === 0 && " <>
        "document.querySelectorAll('[style*=view-transition-name]').length === 0"
    )
  end

  defp navigate(page, hash) do
    js(page, "location.hash = '#{hash}'")
    position = String.trim_leading(hash, "#")

    wait_for(
      page,
      "document.getElementById('slide-#{hd(String.split(position, "."))}').style.display === 'flex'"
    )

    settle(page)
  end

  test "the auto morph moves the heading, the stat and the element with the key", %{
    moving: page
  } do
    page |> press("j") |> started()

    assert length(groups(page)) == 3
    assert js(page, "document.documentElement.dataset.transition") == "fade"

    settle(page)
    assert position(page) == "2.1"
    assert js(page, "document.querySelectorAll('[style*=view-transition-name]').length") == 0
  end

  test "a move back morphs the same elements", %{moving: page} do
    page |> navigate("#2.1") |> press("k") |> started()

    assert length(groups(page)) == 3
    settle(page)
    assert position(page) == "1.1"
  end

  test "the mode named morphs only the elements with a key", %{moving: page} do
    page |> navigate("#2.1") |> press("j") |> started()

    assert groups(page) == ["::view-transition-group(expresso-morph-1)"]
  end

  # The second press comes during the transition from slide 1 to slide 2, and
  # it stops that transition. The end of the stopped transition must not
  # remove the names of the next one.
  test "a key press during a transition keeps the morph of the next change", %{moving: page} do
    press(page, "j")
    wait_for(page, "document.getElementById('slide-2').style.display === 'flex'")
    page |> press("j") |> started()

    assert groups(page) == ["::view-transition-group(expresso-morph-1)"]
    settle(page)
    assert position(page) == "3.1"
  end

  test "the mode off morphs no element", %{moving: page} do
    page |> navigate("#3.1") |> press("j") |> started()

    assert groups(page) == []
    settle(page)
    assert position(page) == "4.1"
  end

  test "a code morphs each token that the two codes share", %{moving: page} do
    page |> navigate("#5.1") |> press("j") |> started()

    # The code element, then each token of x = 1 that x = 1 + 2 also has.
    assert length(groups(page)) > 2
  end

  test "two videos morph when they show the same file, and not when they share the poster", %{
    moving: page
  } do
    page |> navigate("#7.1") |> press("j") |> started()
    assert groups(page) == []
    settle(page)

    page |> press("j") |> started()
    assert length(groups(page)) == 1
  end

  test "a reader who asks for reduced motion gets no morph", %{page: page, tmp_dir: tmp_dir} do
    page |> open(render(Deck, tmp_dir)) |> press("j")

    assert groups(page) == []
    assert position(page) == "2.1"
  end
end
