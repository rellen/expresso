defmodule Expresso.E2E.ZoomTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext, Page}

  # Slide 1 has two steps, with a code element and a text box. Slide 2 has
  # one step.
  defmodule Deck do
    use Expresso

    name "zoom deck"

    slide "one" do
      heading "Zoom"
      steps 2

      code "elixir" do
        text ~S"""
        def greet(name) do
          "Hello, #{name}!"
        end
        """
      end

      text_box do
        text_area(text: "A sentence below the code.")
      end
    end

    slide "two" do
      text_box do
        text_area(text: "Two")
      end
    end
  end

  setup %{page: page, context: context, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))
    speaker = popup(context, fn -> press(audience, "s") end)
    %{audience: audience, speaker: speaker}
  end

  @screen ".screen"
  @current ~s(.handout-page[data-speaker="current"])

  # The box of the first element of a selector in a window, in pixels.
  defp box(page, selector) do
    js(page, """
    (() => {
      const box = document.querySelector(#{JSON.encode!(selector)}).getBoundingClientRect();
      return [box.left, box.top, box.width, box.height];
    })()
    """)
  end

  # The center of the first element of a selector in a window.
  defp center(page, selector) do
    [left, top, width, height] = box(page, selector)
    {left + width / 2, top + height / 2}
  end

  # A point of the box of the slide of a window, from a part of its width
  # and of its height.
  defp at(page, selector, x, y) do
    [left, top, width, height] = box(page, selector)
    {left + x * width, top + y * height}
  end

  defp alt_click_at(page, {x, y}), do: alt_click(page, x, y)
  defp click_at(page, {x, y}), do: click(page, x, y)

  # The scale and the move that the script wrote for the style sheet, or nil
  # for the full slide.
  defp zoom(page) do
    js(page, """
    (() => {
      const root = document.documentElement;
      if (!root.hasAttribute("data-zoomed")) return null;
      return ["--zoom-scale", "--zoom-x", "--zoom-y"]
        .map((name) => parseFloat(root.style.getPropertyValue(name)));
    })()
    """)
  end

  # The scale of the transform of the slide of a window, with three decimal
  # places. A slide with no transform has the scale 1.
  defp scale(page, selector) do
    js(page, """
    (() => {
      const slide = document.querySelector(#{JSON.encode!(selector)});
      const transform = getComputedStyle(slide).transform;
      return transform === "none" ? 1 : Math.round(new DOMMatrix(transform).a * 1000) / 1000;
    })()
    """)
  end

  @zoomed ~s|document.documentElement.hasAttribute("data-zoomed")|

  test "a click with the Alt key on a code element zooms to it, in the two windows", %{
    audience: audience,
    speaker: speaker
  } do
    assert scale(audience, @screen) == 1
    speaker |> alt_click_at(center(speaker, "#{@current} .code"))

    wait_for(audience, @zoomed)
    [factor, x, y] = zoom(speaker)
    assert factor > 1.25
    assert zoom(audience) == [factor, x, y]

    # The transform of each window has the scale of the zoom.
    assert_in_delta scale(audience, @screen), factor, 0.001
    assert_in_delta scale(speaker, @current), factor, 0.001

    # The text of the code element with its margin fills the window in one
    # direction, and each of its edges is in the window. The code element
    # itself has the width of the slide, so the zoom is for its text.
    [left, top, width, height] = box(audience, "#{@screen} .code pre")
    assert left >= 0 and top >= 0 and left + width <= 1280 and top + height <= 720
    assert width > 0.8 * 1280 or height > 0.8 * 720
    assert Enum.at(box(audience, "#{@screen} .code"), 2) > 1280

    # The step did not change.
    assert position(audience) == "1.1"
    assert position(speaker) == "1.1"
  end

  test "the slide covers the window, and the window has no scroll bar", %{audience: audience} do
    audience |> alt_click_at(center(audience, "#{@screen} .code"))
    wait_for(audience, @zoomed)

    [left, top, width, height] = box(audience, @screen)
    assert left <= 0 and top <= 0 and left + width >= 1280 and top + height >= 720

    # The body does not scroll to the part of the slide outside the window.
    {:ok, _result} = Page.mouse_move(audience.guid, timeout: 10_000, x: 640, y: 360)

    assert js(audience, """
           (() => {
             document.querySelector(".screen")
               .dispatchEvent(new WheelEvent("wheel", {deltaY: 400, bubbles: true}));
             return [getComputedStyle(document.body).overflow, scrollX, scrollY];
           })()
           """) == ["hidden", 0, 0]
  end

  test "the page of the speaker view stays in its box", %{speaker: speaker} do
    before = box(speaker, @current)
    next = ~s(.handout-page[data-speaker="next"])
    {x, y} = center(speaker, next)

    speaker |> alt_click_at(at(speaker, @current, 0.9, 0.5))
    wait_for(speaker, @zoomed)

    # The transform makes the page larger, and the cut keeps the visible part
    # on the box that the page had. The page of the next step is thus at its
    # place under the mouse.
    [_left, _top, width, _height] = box(speaker, @current)
    assert width > Enum.at(before, 2) * 1.9

    assert js(speaker, """
           document.elementFromPoint(#{x}, #{y}).closest(".handout-page").dataset.speaker
           """) == "next"

    assert js(
             speaker,
             "getComputedStyle(document.querySelector(#{JSON.encode!(@current)})).clipPath"
           ) =~
             "inset("
  end

  test "the next click with the Alt key shows the full slide", %{
    audience: audience,
    speaker: speaker
  } do
    audience |> alt_click_at(center(audience, "#{@screen} .code"))
    wait_for(speaker, @zoomed)

    audience |> alt_click_at({640, 360})
    wait_for(speaker, "!#{@zoomed}")

    assert zoom(audience) == nil
    assert scale(audience, @screen) == 1
    assert scale(speaker, @current) == 1
    assert position(audience) == "1.1"
  end

  test "Escape shows the full slide in the two windows", %{audience: audience, speaker: speaker} do
    speaker |> alt_click_at(center(speaker, "#{@current} .code"))
    wait_for(audience, @zoomed)

    audience |> press("Escape")
    wait_for(speaker, "!#{@zoomed}")

    assert zoom(audience) == nil
    assert scale(audience, @screen) == 1
  end

  test "the next step shows the full slide in the two windows", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> alt_click_at(center(speaker, "#{@current} .code"))
    wait_for(audience, @zoomed)

    speaker |> press("j")
    wait_for(audience, "location.hash === '#1.2'")

    assert zoom(audience) == nil
    assert zoom(speaker) == nil
    assert scale(audience, @screen) == 1
  end

  test "a click with the Alt key outside each element zooms by 2 around the point", %{
    audience: audience,
    speaker: speaker
  } do
    # The heading is not an element of the body of the slide.
    {x, y} = center(audience, "#{@screen} h1")
    assert_in_delta x, 640, 1
    assert y < 180

    audience |> alt_click_at({x, y})
    wait_for(speaker, @zoomed)

    # The area around the point stays on the slide, so the top edge of the
    # slide stays at the top edge of the window.
    assert zoom(audience) == [2, -0.5, 0]
    assert zoom(speaker) == [2, -0.5, 0]
    assert box(audience, @screen) == [-640, 0, 2560, 1440]
  end

  test "a text that takes most of the width of the slide zooms by 2 around the point", %{
    audience: audience,
    tmp_dir: tmp_dir
  } do
    defmodule Wide do
      use Expresso

      name "wide deck"

      slide "one" do
        text_box do
          text_area(
            text:
              "This sentence is long, so its text takes the full width of the slide " <>
                "and more than one line of it."
          )
        end
      end
    end

    audience |> open(render(Wide, tmp_dir, "wide"))
    audience |> alt_click_at(center(audience, "#{@screen} .text-area"))
    wait_for(audience, @zoomed)

    # The click is at the center of the width of the slide.
    assert [2, -0.5, _y] = zoom(audience)
  end

  test "an element of a later step gives no part of the area", %{
    audience: audience,
    tmp_dir: tmp_dir
  } do
    defmodule Later do
      use Expresso

      name "later deck"

      slide "one" do
        list do
          reveal true
          item "One"
          item "Two, with more text than the first item of this list"
        end
      end
    end

    audience |> open(render(Later, tmp_dir, "later"))
    audience |> alt_click_at(center(audience, "#{@screen} .list li"))
    wait_for(audience, @zoomed)

    # The word of the first item is small, so the scale is the limit. The
    # text of the second item does not show, and it gives no box.
    assert zoom(audience) |> hd() == 4
  end

  test "z turns on a zoom where a click with no key zooms", %{
    audience: audience,
    speaker: speaker
  } do
    cursor = fn -> js(audience, "getComputedStyle(document.querySelector('.screen')).cursor") end
    assert cursor.() == "auto"

    audience |> press("z")
    wait_for(speaker, "document.body.dataset.zoom === 'true'")
    assert cursor.() == "zoom-in"

    audience |> click_at(center(audience, "#{@screen} .code"))
    wait_for(speaker, @zoomed)
    assert cursor.() == "zoom-out"
    assert position(audience) == "1.1"

    # The next click shows the full slide, and the step does not change.
    audience |> click_at({640, 360})
    wait_for(speaker, "!#{@zoomed}")
    assert position(audience) == "1.1"

    # A second z turns the zoom off, and a click then changes the step.
    audience |> press("z")
    assert js(audience, "document.body.dataset.zoom") == nil
    audience |> click_at({1000, 360})
    assert position(audience) == "1.2"
  end

  test "a speaker view that loads after a zoom gets the zoom", %{
    audience: audience,
    speaker: speaker
  } do
    audience |> alt_click_at(center(audience, "#{@screen} .code"))
    wait_for(speaker, @zoomed)
    expected = zoom(audience)

    speaker |> reload()
    wait_for(speaker, @zoomed)

    assert zoom(speaker) == expected
  end

  test "the overview of the speaker view shows no zoom", %{speaker: speaker} do
    speaker |> alt_click_at(center(speaker, "#{@current} .code"))
    wait_for(speaker, @zoomed)
    assert scale(speaker, @current) > 1

    speaker |> press("o")

    assert scale(speaker, @current) == 1

    assert js(
             speaker,
             "getComputedStyle(document.querySelector(#{JSON.encode!(@current)})).clipPath"
           ) ==
             "none"
  end

  test "the dot of the laser pointer is on the same part of a slide with a zoom", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> alt_click_at(center(speaker, "#{@current} .code"))
    wait_for(audience, @zoomed)
    speaker |> press("l")

    {x, y} = center(speaker, "#{@current} .code")
    {:ok, _result} = Page.mouse_move(speaker.guid, timeout: 10_000, x: x, y: y)
    wait_for(audience, ~s|document.getElementById("laser").hasAttribute("data-shown")|)

    # The dot of the present view is on the center of its code element.
    {code_x, code_y} = center(audience, "#{@screen} .code")
    {dot_x, dot_y} = center(audience, "#laser")
    assert_in_delta dot_x, code_x, 2
    assert_in_delta dot_y, code_y, 2
  end

  test "the drawing stays on its part of the slide through a zoom", %{audience: audience} do
    audience |> press("x")
    {:ok, _result} = Page.mouse_move(audience.guid, timeout: 10_000, x: 320, y: 360)
    {:ok, _result} = Page.mouse_down(audience.guid, timeout: 10_000)
    {:ok, _result} = Page.mouse_move(audience.guid, timeout: 10_000, x: 960, y: 360)
    {:ok, _result} = Page.mouse_up(audience.guid, timeout: 10_000)
    wait_for(audience, ~s|document.querySelectorAll("#drawing path").length === 1|)

    # A click with the Alt key draws no dot. The heading is outside each
    # element, so the scale is 2.
    audience |> alt_click_at(center(audience, "#{@screen} h1"))
    wait_for(audience, @zoomed)
    assert js(audience, ~s|document.querySelectorAll("#drawing path").length|) == 1

    # The layer of the drawing is on the box of the slide, so the line is two
    # times as long, and it goes through the window.
    assert box(audience, "#drawing") == box(audience, @screen)
    [left, _top, width, _height] = box(audience, "#drawing path")
    assert_in_delta left, 0, 1
    assert_in_delta width, 1280, 1
  end

  describe "with motion" do
    setup %{browser: browser, tmp_dir: tmp_dir} do
      {:ok, context} =
        Browser.new_context(browser.guid,
          timeout: 10_000,
          viewport: %{width: 1280, height: 720},
          reduced_motion: "no-preference"
        )

      {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
      on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
      %{moving: open(page, render(Deck, tmp_dir, "moving"))}
    end

    test "the transform changes with the speed of the theme", %{moving: moving} do
      assert js(moving, """
             (() => {
               const style = getComputedStyle(document.querySelector(".screen"));
               return [style.transitionProperty, style.transitionDuration];
             })()
             """) == ["transform", "0.3s"]
    end

    test "the window shows no scroll bar while the slide gets smaller", %{moving: moving} do
      overflow = "getComputedStyle(document.body).overflow"
      moving |> alt_click_at(center(moving, ".screen h1"))

      wait_for(
        moving,
        ~s|document.querySelector(".screen").getBoundingClientRect().width === 2560|
      )

      assert js(moving, overflow) == "hidden"

      # The slide is larger than the window for the time of the change, and
      # the body keeps `hidden` for that time.
      assert js(moving, """
             (() => {
               document.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape"}));
               const width = document.querySelector(".screen").getBoundingClientRect().width;
               return [width > 1280, #{overflow}];
             })()
             """) == [true, "hidden"]

      wait_for(moving, ~s|#{overflow} === "visible"|)
      assert box(moving, ".screen") == [0, 0, 1280, 720]
    end

    test "the drawing follows the slide to the end of the change", %{moving: moving} do
      moving |> press("x")
      {:ok, _result} = Page.mouse_move(moving.guid, timeout: 10_000, x: 320, y: 360)
      {:ok, _result} = Page.mouse_down(moving.guid, timeout: 10_000)
      {:ok, _result} = Page.mouse_move(moving.guid, timeout: 10_000, x: 960, y: 360)
      {:ok, _result} = Page.mouse_up(moving.guid, timeout: 10_000)

      moving |> alt_click_at(center(moving, ".screen h1"))

      wait_for(moving, """
      (() => {
        const slide = document.querySelector(".screen").getBoundingClientRect();
        const layer = document.getElementById("drawing").getBoundingClientRect();
        return slide.width === 2560 && layer.width === 2560 && layer.left === slide.left;
      })()
      """)
    end
  end

  test "a reader who asks for reduced motion gets the zoom with no change in progress", %{
    audience: audience
  } do
    assert js(audience, "getComputedStyle(document.querySelector('.screen')).transitionDuration") ==
             "0s"
  end
end
