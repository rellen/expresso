defmodule Expresso.E2E.DocumentTagsTest do
  use Expresso.E2E, async: false

  alias Expresso.Builder

  # The tag `color-scheme` tells the browser the scheme of the theme. The
  # color `Canvas` of the system then follows the theme, and so do the scroll
  # bars. The test reads the color from an element with that color.
  @canvas """
  (() => {
    const probe = document.createElement("div");
    probe.style.backgroundColor = "Canvas";
    document.body.append(probe);
    const color = getComputedStyle(probe).backgroundColor;
    probe.remove();
    return color;
  })()
  """

  # The relative luminance of a color is high for a light color.
  defp light?(color) do
    [red, green, blue] =
      ~r/\d+/ |> Regex.scan(color) |> Enum.take(3) |> Enum.map(fn [n] -> String.to_integer(n) end)

    red + green + blue > 382
  end

  defp deck(theme), do: Builder.deck([Builder.slide("one", heading: "One")], theme: theme)

  test "the colors of the system follow a light theme and a dark theme", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    # The scheme of the screen is the opposite of the theme, so the color
    # comes from the tag and not from the screen.
    light =
      browser |> new_page(color_scheme: :dark) |> open(render(deck(:default), tmp_dir, "light"))

    dark =
      browser |> new_page(color_scheme: :light) |> open(render(deck(:dracula), tmp_dir, "dark"))

    assert light?(js(light, @canvas))
    refute light?(js(dark, @canvas))
  end

  test "with two variants, the colors of the system follow the screen and the key t", %{
    browser: browser,
    tmp_dir: tmp_dir
  } do
    address = render(deck(dark: :dracula, light: :default), tmp_dir)

    page = browser |> new_page(color_scheme: :dark) |> open(address)
    refute light?(js(page, @canvas))

    press(page, "t")
    wait_for(page, "document.documentElement.dataset.scheme === 'light'")
    assert light?(js(page, @canvas))

    press(page, "t")
    wait_for(page, "document.documentElement.dataset.scheme === 'dark'")
    refute light?(js(page, @canvas))
  end

  test "the document has the description and the author of the deck", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    deck =
      Builder.deck([Builder.slide("one", heading: "One")],
        name: "tags",
        description: "A talk about tags.",
        author: "Ada Lovelace"
      )

    page = open(page, render(deck, tmp_dir))

    assert js(page, "document.querySelector('meta[name=description]').content") ==
             "A talk about tags."

    assert js(page, "document.querySelector('meta[name=author]').content") == "Ada Lovelace"
    assert js(page, "document.characterSet") == "UTF-8"
  end
end
