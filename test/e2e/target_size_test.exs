defmodule Expresso.E2E.TargetSizeTest do
  use Expresso.E2E, async: false

  # Criterion 2.5.8 of WCAG 2.2, Target Size (Minimum): a control is 24 by 24
  # CSS pixels or larger. The font size of the document comes from the window,
  # so a small window gives small controls.
  defmodule Deck do
    use Expresso

    name "target deck"

    slide "one" do
      list do
        reveal true
        item "First"
        item "Second"
        item "Third"
      end
    end

    slide "two" do
      text_box do
        text_area(text: "Two")
      end
    end
  end

  # The width and the height of each element of a selector that shows.
  defp sizes(page, selector) do
    js(page, """
    [...document.querySelectorAll(#{JSON.encode!(selector)})]
      .map((element) => element.getBoundingClientRect())
      .filter((box) => box.width > 0 && box.height > 0)
      .map((box) => [box.width, box.height])
    """)
  end

  for {width, height} <- [{1280, 720}, {640, 360}, {320, 480}] do
    test "each option of the menu is 24 pixels high or more in a window of #{width} by #{height}",
         %{browser: browser, tmp_dir: tmp_dir} do
      page = new_page(browser, viewport: %{width: unquote(width), height: unquote(height)})
      page |> open(render(Deck, tmp_dir)) |> press("m")
      wait_for(page, "document.querySelector('#menu [role=option]') !== null")

      options = sizes(page, "#menu [role=option]")

      # Slide 1 has three steps, so the menu has one row for each step.
      assert length(options) >= 4
      for [width, height] <- options, do: assert(width >= 24 and height >= 24)
    end

    test "the search field of the list of keys is 24 pixels high or more in a window of #{width} by #{height}",
         %{browser: browser, tmp_dir: tmp_dir} do
      page = new_page(browser, viewport: %{width: unquote(width), height: unquote(height)})
      page |> open(render(Deck, tmp_dir)) |> press("Shift+Slash")
      wait_for(page, "document.querySelector('#help').open")

      assert [[width, height]] = sizes(page, "#help-filter")
      assert width >= 24 and height >= 24
    end
  end
end
