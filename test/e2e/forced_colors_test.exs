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

  # A deck with the content that needs a rule in forced colors: a chart, a
  # diagram, code with a line in focus, an image and a formula with a part.
  defmodule ContentDeck do
    use Expresso

    name "content deck"

    slide "chart" do
      chart :bar do
        title "Orders and returns each year"
        categories ["2022", "2023"]
        series "Orders", [120, 180]
        series "Returns", [14, 22]
      end
    end

    slide "diagram" do
      diagram "test/fixtures/flow.svg" do
        alt "A request goes from the browser to the server"
      end
    end

    slide "code" do
      code "elixir" do
        text """
        # A comment.
        def one do
          1
        end
        """

        highlight [2..2]
      end
    end

    slide "image" do
      image "test/fixtures/dot.png", alt: "A dot"
    end

    slide "formula" do
      math ~S(<math display="block"><mrow><mi data-part="bind">f</mi><mo>+</mo><mi>g</mi></mrow></math>) do
        part "bind" do
          on 1, set: [color: "rgb(255, 0, 0)"]
        end
      end
    end
  end

  # The same chart in a dark theme. With a white canvas, its light text did
  # not show.
  defmodule DarkDeck do
    use Expresso

    name "dark deck"
    theme :dracula

    slide "chart" do
      chart :bar do
        title "Orders and returns each year"
        categories ["2022", "2023"]
        series "Orders", [120, 180]
        series "Returns", [14, 22]
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

  # The lowest contrast of the texts of the chart with the plate of the chart.
  @chart_texts """
  (() => {
    const parse = (color) => {
      const rgb = /rgba?\\(([\\d.]+),\\s*([\\d.]+),\\s*([\\d.]+)/.exec(color);
      if (rgb) return [+rgb[1], +rgb[2], +rgb[3]];
      const srgb = /color\\(srgb ([\\d.e-]+) ([\\d.e-]+) ([\\d.e-]+)/.exec(color);
      return [srgb[1] * 255, srgb[2] * 255, srgb[3] * 255];
    };
    const part = (value) => {
      const v = value / 255;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
    };
    const light = ([r, g, b]) => 0.2126 * part(r) + 0.7152 * part(g) + 0.0722 * part(b);
    const svg = document.querySelector("#slide-1 .chart svg");
    const plate = parse(getComputedStyle(svg).backgroundColor);
    const ratios = [...svg.querySelectorAll("text")]
      .filter((text) => text.textContent.trim() !== "")
      .map((text) => {
        const [high, low] = [light(parse(getComputedStyle(text).fill)), light(plate)].sort((a, b) => b - a);
        return (high + 0.05) / (low + 0.05);
      });
    return [ratios.length, Math.min(...ratios)];
  })()
  """

  defp style(page, selector, property) do
    js(
      page,
      "getComputedStyle(document.querySelector(#{JSON.encode!(selector)}))[#{JSON.encode!(property)}]"
    )
  end

  for scheme <- @schemes do
    for {deck, ground} <- [{ContentDeck, "rgb(255, 255, 255)"}, {DarkDeck, "rgb(40, 42, 54)"}] do
      # The browser does not change the `fill` of an SVG text, so the chart
      # keeps its colors on a plate with the background color of the theme.
      test "each text of a chart of #{inspect(deck)} has 4.5:1 or more on its plate with the #{scheme} color scheme",
           %{browser: browser, tmp_dir: tmp_dir} do
        page =
          browser
          |> new_page(forced_colors: "active", color_scheme: unquote(scheme))
          |> open(render(unquote(deck), tmp_dir))

        assert style(page, "#slide-1 .chart svg", "forcedColorAdjust") == "none"
        assert rgb(style(page, "#slide-1 .chart svg", "backgroundColor")) == unquote(ground)

        [count, lowest] = js(page, @chart_texts)
        assert count >= 6
        assert lowest >= 4.5
      end
    end

    test "a diagram, an image and a formula with a part have a plate with the #{scheme} color scheme",
         %{browser: browser, tmp_dir: tmp_dir} do
      page =
        browser
        |> new_page(forced_colors: "active", color_scheme: unquote(scheme))
        |> open(render(ContentDeck, tmp_dir))

      for selector <- ["#slide-2 .diagram > svg", "#slide-4 .image img", "#slide-5 .math math"] do
        assert style(page, selector, "forcedColorAdjust") == "none", selector
        assert rgb(style(page, selector, "backgroundColor")) == "rgb(255, 255, 255)", selector
      end

      # The part of the formula keeps the color of its step.
      page |> keys(["j", "j", "j", "j"]) |> wait_for_position("5.1")

      wait_for(
        page,
        "getComputedStyle(document.querySelector('#slide-5 .math-part')).color === 'color(srgb 1 0 0)'"
      )
    end

    # Each text has one color of the system, so the dim state uses the opacity.
    test "a dimmed line of code is different from the line in focus with the #{scheme} color scheme",
         %{browser: browser, tmp_dir: tmp_dir} do
      page =
        browser
        |> new_page(forced_colors: "active", color_scheme: unquote(scheme))
        |> open(render(ContentDeck, tmp_dir))

      page |> keys(["j", "j"]) |> wait_for_position("3.1")

      filters =
        js(page, """
        [...document.querySelectorAll("#slide-3 .code .line")]
          .map((line) => getComputedStyle(line).filter)
        """)

      assert length(filters) == 4
      assert Enum.at(filters, 1) =~ "opacity(1)"
      for index <- [0, 2, 3], do: assert(Enum.at(filters, index) =~ "opacity(0.6)")

      # The two lines have the same color, so only the opacity tells them apart.
      colors =
        js(
          page,
          ~s|[...document.querySelectorAll("#slide-3 .code .line")].map((line) => getComputedStyle(line).color)|
        )

      assert Enum.uniq(colors) |> length() == 1
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

  test "the usual mode gives a chart no plate, and it dims a line of code with a color",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(ContentDeck, tmp_dir))

    assert style(page, "#slide-1 .chart svg", "backgroundColor") == "rgba(0, 0, 0, 0)"
    assert style(page, "#slide-1 .chart svg", "forcedColorAdjust") == "auto"

    page |> keys(["j", "j"]) |> wait_for_position("3.1")

    filters =
      js(
        page,
        ~s|[...document.querySelectorAll("#slide-3 .code .line")].map((line) => getComputedStyle(line).filter)|
      )

    for filter <- filters, do: assert(filter =~ "opacity(1)")
  end
end
