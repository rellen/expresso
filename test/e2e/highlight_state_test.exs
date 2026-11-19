defmodule Expresso.E2E.HighlightStateTest do
  use Expresso.E2E, async: false

  # The state `highlight` from an `on` entity draws a bar at the left of the
  # element. Each element with the state gets it at step 2.
  # `docs/dim-state.md` gives the design.
  defmodule Deck do
    use Expresso

    name "highlight deck"

    slide "text" do
      text_box do
        text_area do
          text "A text"
          on 2, state: :highlight
        end

        list do
          item "One" do
            on 2, state: :highlight
          end

          item "Two"
        end
      end

      table do
        row ["j", "The next step"] do
          on 2, state: :highlight
        end
      end

      code "elixir" do
        text "def one, do: 1"
        on 2, state: :highlight
      end

      footnote "A source." do
        on 2, state: :highlight
      end
    end

    slide "boxes" do
      columns do
        column do
          stat 1250 do
            label "orders"
            on 2, state: :highlight
          end

          image "test/fixtures/dot.png" do
            alt "A dot"
            on 2, state: :highlight
          end
        end

        column do
          on 2, state: :highlight

          callout :warning do
            text_area(text: "A warning.")
            on 2, state: :highlight
          end
        end
      end
    end

    slide "tree" do
      tree do
        title "The plant"

        node "Ana" do
          node "Ben" do
            on 2, state: :highlight
          end

          node "Eve"
        end
      end
    end
  end

  # The selectors of the elements with the state, on each slide. The bar of a
  # node of a tree is on its box.
  @elements %{
    1 => ~w(.text-area .item .row .code .footnote),
    2 => ~w(.stat .image .column[data-el] .callout),
    3 => [".tree-node[data-el] > .tree-box"]
  }

  @accent "rgb(52, 101, 164)"

  # The computed style of the bar of each element, and the size of the bar
  # and of the element.
  defp bars(page, scope, slide) do
    selectors = Map.fetch!(@elements, slide)

    js(page, """
    #{JSON.encode!(selectors)}.map((selector) => {
      const element = document.querySelector(#{JSON.encode!(scope)} + " " + selector);
      const bar = getComputedStyle(element, "::before");
      return {
        selector,
        content: bar.content,
        position: bar.position,
        opacity: bar.opacity,
        color: bar.backgroundColor,
        adjust: bar.forcedColorAdjust,
        print: bar.printColorAdjust,
        width: parseFloat(bar.width),
        height: parseFloat(bar.height),
        element: element.getBoundingClientRect().height
      };
    })
    """)
  end

  defp screen(slide), do: "#slide-#{slide}"

  defp assert_bars(bars, opacity, color) do
    for bar <- bars do
      assert bar["content"] == ~s(""), bar["selector"]
      assert bar["position"] == "absolute", bar["selector"]
      assert bar["opacity"] == opacity, bar["selector"]
      assert rgb(bar["color"]) == color, bar["selector"]
      assert bar["width"] >= 3, bar["selector"]
      assert bar["height"] > 0, bar["selector"]
    end
  end

  # Wait for the end of the transition of each bar of a slide.
  defp wait_for_bars(page, scope, slide) do
    wait_for(page, """
    #{JSON.encode!(Map.fetch!(@elements, slide))}.every((selector) =>
      getComputedStyle(document.querySelector(#{JSON.encode!(scope)} + " " + selector), "::before")
        .opacity === "1")
    """)
  end

  # The place of each element in the slides. The bar has an absolute
  # position, so these places are the same without the bar.
  @places """
  [...document.querySelectorAll("section.slide *")].map((element) => {
    const box = element.getBoundingClientRect();
    return [box.x, box.y, box.width, box.height].map((value) => Math.round(value * 100));
  })
  """

  test "an element with the state has a bar in the accent color at its step",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))

    page |> bars(screen(1), 1) |> assert_bars("0", @accent)

    for slide <- [1, 2, 3] do
      page |> keys(if slide == 1, do: ["j"], else: ["j", "j"]) |> wait_for_position("#{slide}.2")
      wait_for_bars(page, screen(slide), slide)

      bars = bars(page, screen(slide), slide)
      assert_bars(bars, "1", @accent)

      # A bar has the height of its element. The bar of a box of a tree is
      # inside the box.
      for bar <- bars, slide != 3 do
        assert_in_delta bar["height"], bar["element"], 1, bar["selector"]
      end
    end
  end

  test "an element without the state has no bar", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))
    page |> press("j") |> wait_for_position("1.2")
    wait_for_bars(page, screen(1), 1)

    bars =
      js(page, """
      [...document.querySelectorAll("#slide-1 .item")].map((item) => {
        const bar = getComputedStyle(item, "::before");
        return [bar.content, bar.opacity];
      })
      """)

    assert [[~s(""), "1"], ["none", _opacity]] = bars
  end

  test "the bar does not move the content of an element", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))
    page |> press("j") |> wait_for_position("1.2")
    wait_for_bars(page, screen(1), 1)

    before = js(page, @places)

    js(page, """
    (() => {
      const style = document.createElement("style");
      style.textContent = "*::before { display: none !important; }";
      document.head.append(style);
    })()
    """)

    assert js(page, @places) == before
  end

  test "the handout view and paper show the bar at its step", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))
    press(page, "p")

    page |> bars(".handout-page[data-step='1']", 1) |> assert_bars("0", @accent)

    bars = bars(page, ".handout-page[data-step='2']", 1)
    assert_bars(bars, "1", @accent)
    for bar <- bars, do: assert(bar["print"] == "exact")
  end

  for {scheme, color} <- [light: "rgb(0, 0, 0)", dark: "rgb(255, 255, 255)"] do
    # The browser removes each `box-shadow` and gives a background the color
    # of the canvas, so the bar has the color of the text.
    test "the bar has the color of the text in forced colors with the #{scheme} color scheme",
         %{browser: browser, tmp_dir: tmp_dir} do
      page =
        browser
        |> new_page(forced_colors: "active", color_scheme: unquote(scheme))
        |> open(render(Deck, tmp_dir))

      page |> bars(screen(1), 1) |> assert_bars("0", unquote(color))

      page |> press("j") |> wait_for_position("1.2")
      wait_for_bars(page, screen(1), 1)

      bars = bars(page, screen(1), 1)
      assert_bars(bars, "1", unquote(color))
      for bar <- bars, do: assert(bar["adjust"] == "none")

      page |> keys(["j", "j", "j", "j"]) |> wait_for_position("3.2")
      wait_for_bars(page, screen(3), 3)

      page |> bars(screen(3), 3) |> assert_bars("1", unquote(color))
    end
  end
end
