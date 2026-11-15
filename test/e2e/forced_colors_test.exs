defmodule Expresso.E2E.ForcedColorsTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.Page

  # Forced colors, such as the high contrast mode of Windows. The browser
  # replaces the colors of the page with the colors of the system. With the
  # light color scheme the canvas is white, and with the dark color scheme it
  # is black. `docs/accessibility-preferences.md` gives the design.
  defmodule Deck do
    use Expresso

    name "forced deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      text_box do
        text_area(text: "Two")
      end
    end
  end

  @schemes [:light, :dark]

  # The contrast of a color of an element with the canvas, as WCAG calculates
  # it. `property` is a property of the computed style, such as `stroke`. The
  # opacity of the element makes its color nearer to the canvas.
  @contrast """
  ((selector, property) => {
    const parse = (color) => {
      const rgb = /rgba?\\(([\\d.]+),\\s*([\\d.]+),\\s*([\\d.]+)(?:,\\s*([\\d.]+))?\\)/.exec(color);
      if (rgb) return [+rgb[1], +rgb[2], +rgb[3], rgb[4] === undefined ? 1 : +rgb[4]];
      const srgb = /color\\(srgb ([\\d.e-]+) ([\\d.e-]+) ([\\d.e-]+)(?: \\/ ([\\d.]+))?\\)/.exec(color);
      return [srgb[1] * 255, srgb[2] * 255, srgb[3] * 255, srgb[4] === undefined ? 1 : +srgb[4]];
    };
    const part = (value) => {
      const v = value / 255;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
    };
    const light = ([r, g, b]) => 0.2126 * part(r) + 0.7152 * part(g) + 0.0722 * part(b);
    const canvas = parse(getComputedStyle(document.documentElement).backgroundColor);
    const style = getComputedStyle(document.querySelector(selector));
    const color = parse(style[property]);
    const alpha = color[3] * Number(style.opacity);
    const shown = color.slice(0, 3).map((v, i) => v * alpha + canvas[i] * (1 - alpha));
    const [high, low] = [light(shown), light(canvas)].sort((a, b) => b - a);
    return (high + 0.05) / (low + 0.05);
  })
  """

  defp contrast(page, selector, property) do
    js(page, "#{@contrast}(#{JSON.encode!(selector)}, #{JSON.encode!(property)})")
  end

  defp forced(browser, scheme, tmp_dir) do
    browser
    |> new_page(forced_colors: "active", color_scheme: scheme)
    |> open(render(Deck, tmp_dir))
  end

  defp move(page, x, y) do
    {:ok, _result} = Page.mouse_move(page.guid, timeout: 10_000, x: x, y: y)
    page
  end

  defp drag(page, {x1, y1}, {x2, y2}) do
    move(page, x1, y1)
    {:ok, _result} = Page.mouse_down(page.guid, timeout: 10_000)
    move(page, x2, y2)
    {:ok, _result} = Page.mouse_up(page.guid, timeout: 10_000)
    page
  end

  for scheme <- @schemes do
    test "the page has the forced colors of the #{scheme} color scheme",
         %{browser: browser, tmp_dir: tmp_dir} do
      page = forced(browser, unquote(scheme), tmp_dir)

      assert js(page, "matchMedia('(forced-colors: active)').matches") == true

      canvas = js(page, "getComputedStyle(document.documentElement).backgroundColor")

      assert canvas ==
               if(unquote(scheme) == :dark, do: "rgb(0, 0, 0)", else: "rgb(255, 255, 255)")
    end

    # The bar is a box with only a background color, and the browser gives
    # such a box the color of the canvas.
    test "the progress bar shows in forced colors with the #{scheme} color scheme",
         %{browser: browser, tmp_dir: tmp_dir} do
      page = forced(browser, unquote(scheme), tmp_dir)
      page |> press("j") |> wait_for_position("2.1")

      assert js(page, "getComputedStyle(document.querySelector('#progress')).display") == "block"
      assert contrast(page, "#progress", "backgroundColor") >= 3
    end

    # The browser removes the `box-shadow` of the dot, so a ring of the text
    # color marks its edge.
    test "the laser pointer shows in forced colors with the #{scheme} color scheme",
         %{browser: browser, tmp_dir: tmp_dir} do
      page = forced(browser, unquote(scheme), tmp_dir)
      page |> press("l") |> move(400, 300) |> move(420, 320)
      wait_for(page, "getComputedStyle(document.querySelector('#laser')).display === 'block'")

      assert contrast(page, "#laser", "backgroundColor") >= 3
      assert contrast(page, "#laser", "outlineColor") >= 3

      assert js(page, "getComputedStyle(document.querySelector('#laser')).outlineStyle") ==
               "solid"
    end

    test "a line of the pen has a contrast of 3 or more in forced colors with the #{scheme} color scheme",
         %{browser: browser, tmp_dir: tmp_dir} do
      page = forced(browser, unquote(scheme), tmp_dir)
      page |> press("x") |> drag({300, 300}, {500, 380})
      wait_for(page, "document.querySelector('#drawing .drawing-pen') !== null")

      assert contrast(page, "#drawing .drawing-pen", "stroke") >= 3
    end

    # A line of the highlighter lets the text under it show, so it has an
    # opacity. It is not the canvas color.
    test "a line of the highlighter shows in forced colors with the #{scheme} color scheme",
         %{browser: browser, tmp_dir: tmp_dir} do
      page = forced(browser, unquote(scheme), tmp_dir)
      page |> press("x") |> press("h") |> drag({300, 300}, {500, 380})
      wait_for(page, "document.querySelector('#drawing .drawing-highlighter') !== null")

      assert contrast(page, "#drawing .drawing-highlighter", "stroke") >= 2
    end
  end

  # In the usual mode, a deck can change these colors, and the rules for forced
  # colors do not apply.
  test "the usual mode keeps the colors of the theme", %{page: page, tmp_dir: tmp_dir} do
    page |> open(render(Deck, tmp_dir)) |> press("j") |> wait_for_position("2.1")

    assert js(page, "matchMedia('(forced-colors: active)').matches") == false

    assert rgb(js(page, "getComputedStyle(document.querySelector('#progress')).backgroundColor")) ==
             "rgb(52, 101, 164)"
  end
end
