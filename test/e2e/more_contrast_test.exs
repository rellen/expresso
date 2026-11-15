defmodule Expresso.E2E.MoreContrastTest do
  use Expresso.E2E, async: false

  alias Expresso.Builder
  alias Expresso.Palette

  # A user can ask the system for more contrast. The media query
  # `prefers-contrast: more` is then true, and each role of text has the
  # enhanced minimum of WCAG 2.2, criterion 1.4.6: 7:1 on its background.
  defmodule Deck do
    use Expresso

    name "contrast deck"
    dim_contrast 4

    slide "one" do
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

    slide "two" do
      text_box do
        text_area(text: "Two")
      end
    end
  end

  # Each role of text, each dimmed role and the property of its background.
  @pairs (for {role, {_slot, on}} <- Palette.roles(), on != nil do
            property = &("--" <> String.replace(Atom.to_string(&1), "_", "-"))
            [[property.(role), property.(on)], [property.(role) <> "-dim", property.(on)]]
          end)
         |> Enum.concat()

  # The contrast ratio of WCAG of each pair of properties of the `html`
  # element, as the browser reads them with the preferences of the page.
  @ratios """
  ((pairs) => {
    const style = getComputedStyle(document.documentElement);
    const part = (value) => {
      const v = value / 255;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
    };
    const light = (name) => {
      const hex = style.getPropertyValue(name).trim();
      const [r, g, b] = [1, 3, 5].map((at) => parseInt(hex.slice(at, at + 2), 16));
      return 0.2126 * part(r) + 0.7152 * part(g) + 0.0722 * part(b);
    };
    return pairs.map(([text, ground]) => {
      const [high, low] = [light(text), light(ground)].sort((a, b) => b - a);
      return [text, (high + 0.05) / (low + 0.05)];
    });
  })
  """

  defp ratios(page), do: js(page, "#{@ratios}(#{JSON.encode!(@pairs)})")

  defp more(browser, options \\ []),
    do: new_page(browser, Keyword.merge([contrast: "more"], options))

  defp theme_deck(theme), do: Builder.deck([Builder.slide("one")], theme: theme)

  test "each role of text of each built-in theme has 7:1 or more, also when it is dimmed",
       %{browser: browser, tmp_dir: tmp_dir} do
    page = more(browser)

    for name <- Palette.Builtin.names() do
      open(page, render(theme_deck(name), tmp_dir, Atom.to_string(name)))
      ratios = ratios(page)

      assert length(ratios) == 36

      # The browser and `Expresso.Color` calculate the ratio in a different
      # sequence, so the last digits can be different.
      for [property, ratio] <- ratios do
        assert ratio >= 6.999, "#{property} of #{name} has #{ratio}:1"
      end
    end
  end

  test "the usual mode keeps the colors of the theme", %{page: page, tmp_dir: tmp_dir} do
    ratios =
      page |> open(render(theme_deck(:default), tmp_dir)) |> ratios() |> Map.new(&List.to_tuple/1)

    assert_in_delta ratios["--accent"], 5.9, 0.05
    assert ratios["--text-dim"] < 4
  end

  test "each variant of a theme with two variants has 7:1 or more, also after the key t",
       %{browser: browser, tmp_dir: tmp_dir} do
    address = render(theme_deck(dark: :zenburn, light: :one_light), tmp_dir)

    for scheme <- [:light, :dark] do
      page = browser |> more(color_scheme: scheme) |> open(address)

      first =
        js(page, "getComputedStyle(document.documentElement).getPropertyValue('--background')")

      for [property, ratio] <- ratios(page),
          do: assert(ratio >= 6.999, "#{property} with #{scheme}")

      # The key `t` writes `data-scheme`, and the other variant then shows.
      press(page, "t")
      wait_for(page, "document.documentElement.dataset.scheme !== undefined")

      second =
        js(page, "getComputedStyle(document.documentElement).getPropertyValue('--background')")

      assert first != second
      for [property, ratio] <- ratios(page), do: assert(ratio >= 6.999, "#{property} after t")
    end
  end

  # The deck has `dim_contrast 4`. The preference gives 7, which is the
  # highest value of the option.
  test "a dimmed line of code has 7:1 or more in a deck with a lower dim_contrast option",
       %{browser: browser, tmp_dir: tmp_dir} do
    contrast = """
    (() => {
      const part = (value) => {
        const v = value / 255;
        return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
      };
      const light = (color) => {
        const srgb = /color\\(srgb ([\\d.e-]+) ([\\d.e-]+) ([\\d.e-]+)/.exec(color);
        const [r, g, b] = srgb
          ? [srgb[1] * 255, srgb[2] * 255, srgb[3] * 255]
          : /rgba?\\(([\\d.]+),\\s*([\\d.]+),\\s*([\\d.]+)/.exec(color).slice(1).map(Number);
        return 0.2126 * part(r) + 0.7152 * part(g) + 0.0722 * part(b);
      };
      const ground = getComputedStyle(document.querySelector("#slide-1 .code code")).backgroundColor;
      return [...document.querySelectorAll("#slide-1 .code .line, #slide-1 .code .line span")].map((text) => {
        const [high, low] = [light(getComputedStyle(text).color), light(ground)].sort((a, b) => b - a);
        return (high + 0.05) / (low + 0.05);
      });
    })()
    """

    usual = new_page(browser, []) |> open(render(Deck, tmp_dir)) |> js(contrast)
    with_more = browser |> more() |> open(render(Deck, tmp_dir)) |> js(contrast)

    # Line 2 is in focus, and each other line is dimmed.
    assert length(usual) >= 10
    assert Enum.min(usual) < 5
    for ratio <- with_more, do: assert(ratio >= 6.999)
  end

  test "the outline of the cursor of the menu and of the search field is 3 pixels wide",
       %{browser: browser, tmp_dir: tmp_dir} do
    width = fn page, selector ->
      js(page, "getComputedStyle(document.querySelector(#{JSON.encode!(selector)})).outlineWidth")
    end

    for {page, cursor, search} <- [
          {new_page(browser, []), "2px", "0px"},
          {more(browser), "3px", "3px"}
        ] do
      page |> open(render(Deck, tmp_dir)) |> press("m")
      wait_for(page, "document.querySelector('.menu-step[data-cursor]') !== null")
      assert width.(page, ".menu-step[data-cursor]") == cursor

      page |> press("m") |> press("Shift+Slash")
      wait_for(page, "document.querySelector('#help').open")
      wait_for(page, "document.activeElement === document.querySelector('#help-filter')")
      assert width.(page, "#help-filter") == search
    end
  end
end
