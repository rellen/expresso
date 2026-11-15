defmodule Expresso.E2E.SmallWindowTest do
  use Expresso.E2E, async: false

  # A window smaller than 1280 by 720 pixels shows the slide of that size at a
  # smaller scale: the font size of the `html` element follows the window.
  # `docs/small-windows.md` gives the design.
  defmodule Deck do
    use Expresso

    name "small deck"

    slide "words" do
      heading "Orders each year in each region"

      text_box do
        text_area(text: "A deck from the DSL. Each text of a slide must show in a small window.")
      end
    end

    slide "moves" do
      heading "A box that moves"

      text_box do
        on 2, set: [x: "-200px"]
        text_area(text: "It moves left at step 2.")
      end

      list do
        reveal true
        item "One"
        item "Two"
      end
    end

    slide "code" do
      code "elixir" do
        text """
        def handle_call(:increment, _from, count) do
          {:reply, count + 1, count + 1}
        end
        """
      end
    end
  end

  @phones [{390, 844}, {844, 390}]

  defp phone(browser, width, height) do
    new_page(browser,
      viewport: %{width: width, height: height},
      is_mobile: true,
      has_touch: true,
      device_scale_factor: 2.0
    )
  end

  # The distance in pixels that a text of the slide that shows is outside the
  # window, and the width of the document. A text is an element with a text
  # node of its own.
  @outside """
  (() => {
    const slide = [...document.querySelectorAll(".screen > section")]
      .find((section) => getComputedStyle(section).display !== "none");
    let outside = 0;
    for (const element of slide.querySelectorAll("*")) {
      const own = [...element.childNodes].some((node) => node.nodeType === 3 && node.data.trim() !== "");
      if (!own || getComputedStyle(element).visibility === "hidden") continue;
      const range = document.createRange();
      range.selectNodeContents(element);
      for (const box of range.getClientRects()) {
        outside = Math.max(outside, box.right - innerWidth, -box.left, box.bottom - innerHeight, -box.top);
      }
    }
    return [Math.round(outside), document.documentElement.scrollWidth, innerWidth];
  })()
  """

  defp font_size(page),
    do: js(page, "parseFloat(getComputedStyle(document.documentElement).fontSize)")

  for {width, height} <- @phones do
    test "each text of each step shows in a window of #{width} by #{height}", %{
      browser: browser,
      tmp_dir: tmp_dir
    } do
      page = browser |> phone(unquote(width), unquote(height)) |> open(render(Deck, tmp_dir))

      positions =
        Enum.reduce_while(1..12, [], fn _each, positions ->
          position = js(page, "location.hash")
          [outside, document, window] = js(page, @outside)

          assert outside == 0, "a text is #{outside} px outside the window at #{position}"
          # The document is as wide as the window, so the page does not move
          # to the left or to the right.
          assert document == window
          assert window == unquote(width)

          press(page, "j")

          if js(page, "location.hash") == position,
            do: {:halt, [position | positions]},
            else: {:cont, [position | positions]}
        end)

      # The deck has three slides, and slide 2 has two steps.
      assert Enum.reverse(positions) == ["", "#2.1", "#2.2", "#3.1"]
    end
  end

  test "the font size follows the width and the height of a small window", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    address = render(Deck, tmp_dir)

    for {width, height, size} <- [
          {390, 844, 14.625},
          {844, 390, 26.0},
          {1024, 768, 38.4},
          {1280, 720, 48.0},
          {1920, 1080, 48.0},
          {2560, 600, 40.0}
        ] do
      page = browser |> new_page(viewport: %{width: width, height: height}) |> open(address)

      assert_in_delta font_size(page), size, 0.01, "#{width} by #{height}"
    end
  end

  # The menu and the list of keys are not a slide, so their text keeps its
  # size in a small window.
  test "the menu and the list of keys keep the size of their text in a small window", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    address = render(Deck, tmp_dir)

    sizes =
      for {width, height} <- [{390, 844}, {1280, 720}] do
        page = browser |> new_page(viewport: %{width: width, height: height}) |> open(address)
        press(page, "m")
        wait_for(page, "document.querySelector('#menu .menu-step') !== null")
        row = js(page, "getComputedStyle(document.querySelector('#menu .menu-step')).fontSize")

        page |> press("m") |> press("Shift+Slash")
        wait_for(page, "document.querySelector('#help').open")
        {row, js(page, "getComputedStyle(document.querySelector('#help')).fontSize")}
      end

    assert sizes == [{"14.4px", "17.28px"}, {"14.4px", "17.28px"}]
  end

  # A deck gives a length in pixels, and the length is a length of the slide.
  # It becomes smaller with the text of the slide.
  test "a length of the deck in pixels follows the scale of the slide", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    address = render(Deck, tmp_dir)

    left = "document.querySelector('#slide-2 .text-box').getBoundingClientRect().left"

    moved = fn width, height ->
      page = browser |> new_page(viewport: %{width: width, height: height}) |> open(address)
      page |> press("j") |> wait_for_position("2.1")
      before = js(page, left)
      page |> press("j") |> wait_for_position("2.2")
      js(page, left) - before
    end

    assert_in_delta moved.(1280, 720), -200, 0.5
    assert_in_delta moved.(640, 360), -100, 0.5
    assert_in_delta moved.(390, 844), -200 * 390 / 1280, 0.5
  end

  test "a tap goes to the next step on a phone", %{browser: browser, tmp_dir: tmp_dir} do
    page = browser |> phone(390, 844) |> open(render(Deck, tmp_dir))

    page |> tap(300, 400) |> wait_for_position("2.1")
    page |> tap(300, 400) |> wait_for_position("2.2")
  end

  test "the user can still zoom the page" do
    html = [Expresso.Builder.slide("one")] |> Expresso.Builder.deck() |> Expresso.Deck.render()

    assert html =~ ~s(<meta name="viewport" content="width=device-width, initial-scale=1"/>)
    refute html =~ "user-scalable"
    refute html =~ "maximum-scale"
  end
end
