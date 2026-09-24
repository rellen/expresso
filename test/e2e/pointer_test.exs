defmodule Expresso.E2E.PointerTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # Two slides. Slide 1 has one step, and slide 2 has two steps. The viewport
  # is 1280 pixels wide, so the left third ends at about 427.
  defmodule Deck do
    use Expresso

    name "pointer deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      steps 2

      text_box do
        text_area(text: "Two")
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    url = render(Deck, tmp_dir)
    %{page: open(page, url), url: url}
  end

  test "a click on the right two thirds goes forward, and on the left third goes back", %{
    page: page
  } do
    page |> click(1000, 360)
    assert position(page) == "2.1"

    page |> click(500, 600)
    assert position(page) == "2.2"

    page |> click(100, 360)
    assert position(page) == "2.1"
    assert js(page, "location.hash") == "#2.1"
  end

  test "a click closes a black screen, and it does nothing more", %{page: page} do
    page |> press("b") |> click(1000, 360)

    assert js(page, "document.body.dataset.blank") == nil
    assert position(page) == "1.1"
  end

  test "a click in the handout view does not move", %{page: page} do
    page |> press("p") |> click(1000, 360)

    assert js(page, "location.hash") == "#1.1"
    page |> press("p")
    assert position(page) == "1.1"
  end

  test "a swipe to the left goes forward, and a swipe to the right goes back", %{page: page} do
    page |> swipe({900, 360}, {600, 380})
    assert position(page) == "2.1"

    page |> swipe({900, 360}, {600, 340})
    assert position(page) == "2.2"

    page |> swipe({300, 360}, {700, 360})
    assert position(page) == "2.1"

    # A vertical movement is not a swipe.
    page |> swipe({600, 100}, {620, 600})
    assert position(page) == "2.1"
  end

  test "a tap on a touch screen goes forward", %{browser: browser, url: url} do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: 10_000,
        viewport: %{width: 1280, height: 720},
        has_touch: true
      )

    on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
    {:ok, touch} = BrowserContext.new_page(context.guid, timeout: 10_000)

    touch |> open(url) |> tap(1000, 360)
    assert position(touch) == "2.1"

    touch |> tap(100, 360)
    assert position(touch) == "1.1"
  end

  test "f puts the document in full screen, and f again takes it out", %{page: page} do
    page |> press("f")
    wait_for(page, "document.fullscreenElement === document.documentElement")

    page |> press("f")
    wait_for(page, "document.fullscreenElement === null")
    assert position(page) == "1.1"
  end
end
