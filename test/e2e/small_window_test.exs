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

  # A part of a formula and a part of a diagram that move by 40 pixels at
  # step 2.
  defmodule PartsDeck do
    use Expresso

    slide "parts" do
      math ~S(<math display="block"><mrow><mi data-part="bind">f</mi><mo>+</mo><mi>g</mi></mrow></math>) do
        part "bind" do
          on 2, set: [x: "40px"]
        end
      end

      diagram "test/fixtures/move.svg" do
        part "token" do
          on 2, set: [x: "40px"]
        end
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

  # A pixel of a part of a formula is a pixel of the slide. A pixel of a part
  # of a diagram is a unit of its SVG file, and the browser draws the file at
  # the scale of the slide.
  test "a length in pixels of a part of a formula follows the scale, and a part of a diagram keeps its units",
       %{browser: browser, tmp_dir: tmp_dir} do
    address = render(PartsDeck, tmp_dir)

    left = fn page, selector ->
      js(page, "document.querySelector('.screen #{selector}').getBoundingClientRect().left")
    end

    unit = "document.querySelector('.screen .diagram svg').getBoundingClientRect().width / 400"

    # The distance of each move in the pixels of the window, and the width
    # of one unit of the SVG file in the same pixels.
    moved = fn width, height ->
      page = browser |> new_page(viewport: %{width: width, height: height}) |> open(address)
      formula = left.(page, ~s([data-part="bind"]))
      diagram = left.(page, ~s([id^="token-"]))
      page |> press("j") |> wait_for_position("1.2")

      {left.(page, ~s([data-part="bind"])) - formula, left.(page, ~s([id^="token-"])) - diagram,
       js(page, unit)}
    end

    {formula, diagram, unit} = moved.(1280, 720)
    assert_in_delta formula, 40, 0.5
    assert_in_delta diagram / unit, 40, 0.5

    {formula, diagram, unit} = moved.(640, 360)
    assert_in_delta formula, 20, 0.5
    assert_in_delta diagram / unit, 40, 0.5
  end

  # A phone in the portrait direction shows a tall slide that fills the
  # window. `docs/small-windows.md` gives the reason.
  test "a phone in the portrait direction shows a tall slide that fills the window", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    page = browser |> phone(390, 844) |> open(render(Deck, tmp_dir))

    box =
      js(page, """
      (() => {
        const box = document.querySelector("#slide-1").getBoundingClientRect();
        return [box.left, box.top, box.width, box.height];
      })()
      """)

    assert box == [0, 0, 390, 844]
  end

  # The bars of the browser of a phone cover the bottom of the window while
  # they show. `svh` is the height of the window with the bars, so the bottom
  # of the slide stays in view. The emulation of Chromium has no such bars,
  # so the test reads the rules and measures the slide in the window.
  test "the height of the window is the small viewport height", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    page = browser |> phone(390, 844) |> open(render(Deck, tmp_dir))

    rules =
      js(page, """
      (() => {
        const rules = [...document.styleSheets].flatMap((sheet) => [...sheet.cssRules]);
        const rule = (selector) => rules.find((each) => each.selectorText === selector)?.style;
        return [rule(".screen").height, rule("html").fontSize, document.body.style.minHeight];
      })()
      """)

    # The browser writes `100svh * 48 / 720` as `6.66667svh`.
    assert ["100svh", font_size, "100svh"] = rules
    assert font_size =~ "svh"

    bottoms =
      js(page, """
      [".screen", "#slide-1", "#progress"].map((selector) =>
        document.querySelector(selector).getBoundingClientRect().bottom)
      """)

    assert Enum.all?(bottoms, &(&1 <= 844))
  end

  # The button of the menu shows only where the main pointer is coarse, such
  # as a finger on a phone.
  test "the button of the menu shows on a touch screen, and not with a mouse", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    address = render(Deck, tmp_dir)
    display = "getComputedStyle(document.querySelector('#menu-button')).display"

    phone = browser |> phone(390, 844) |> open(address)
    assert js(phone, "matchMedia('(pointer: coarse)').matches")
    assert js(phone, display) == "flex"

    computer = browser |> new_page(viewport: %{width: 390, height: 844}) |> open(address)
    refute js(computer, "matchMedia('(pointer: coarse)').matches")
    assert js(computer, display) == "none"

    # A black screen, the handout view and paper do not show it.
    press(phone, "b")
    assert js(phone, display) == "none"
    phone |> press("j") |> press("p")
    assert js(phone, display) == "none"
    phone |> press("p") |> emulate("print")
    assert js(phone, display) == "none"
  end

  test "a tap on the button of the menu opens the menu, and a second tap closes it", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    page = browser |> phone(390, 844) |> open(render(Deck, tmp_dir))

    [x, y, width, height] =
      js(page, """
      (() => {
        const box = document.querySelector("#menu-button").getBoundingClientRect();
        return [box.left, box.top, box.width, box.height];
      })()
      """)

    # Criterion 2.5.8 of WCAG 2.2 gives a control 24 by 24 CSS pixels or more.
    assert width >= 24 and height >= 24
    # The button is in the top right corner of the window.
    assert x + width <= 390 and x > 300 and y >= 0 and y < 30

    {center_x, center_y} = {x + width / 2, y + height / 2}
    expanded = "document.querySelector('#menu-button').getAttribute('aria-expanded')"
    assert js(page, expanded) == "false"

    tap(page, center_x, center_y)
    wait_for(page, "document.body.dataset.menu === 'true'")
    assert js(page, expanded) == "true"
    assert js(page, "getComputedStyle(document.querySelector('#menu')).display") == "block"

    # The button is over the menu, so a second tap reaches it.
    assert js(
             page,
             "document.elementFromPoint(#{center_x}, #{center_y}).closest('#menu-button') !== null"
           )

    tap(page, center_x, center_y)
    wait_for(page, "document.body.dataset.menu !== 'true'")
    assert js(page, expanded) == "false"
    # The taps do not change the step.
    assert position(page) == "1.1"
  end

  test "the button of the menu has a border in forced colors", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    page =
      browser
      |> new_page(
        viewport: %{width: 390, height: 844},
        is_mobile: true,
        has_touch: true,
        forced_colors: "active"
      )
      |> open(render(Deck, tmp_dir))

    style = "getComputedStyle(document.querySelector('#menu-button'))"
    assert js(page, "#{style}.display") == "flex"
    assert js(page, "#{style}.borderTopStyle") == "solid"
    assert js(page, "#{style}.borderTopWidth") == "1px"
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
