defmodule Expresso.E2E.ThemeTest do
  use Expresso.E2E, async: false

  alias Expresso.Builder

  defp deck do
    Builder.deck(
      [
        Builder.slide("one",
          heading: "Theme",
          elements: [Builder.code("elixir", text: "# a comment\nx = 1")]
        )
      ],
      name: "theme deck",
      theme: :dracula
    )
  end

  # The computed colors of the page, the heading, a code block and its comment.
  defp colors(page) do
    js(page, """
    (() => {
      const color = (selector, property) =>
        getComputedStyle(document.querySelector(selector))[property];
      return [
        color("html", "backgroundColor"),
        color(".screen h1", "color"),
        color(".screen .highlight", "backgroundColor"),
        color(".screen .highlight .c1", "color"),
      ];
    })()
    """)
  end

  defp hex_rgb("#" <> hex) do
    [r, g, b] = for <<pair::binary-2 <- hex>>, do: String.to_integer(pair, 16)
    "rgb(#{r}, #{g}, #{b})"
  end

  test "the screen gets the colors of the theme, and paper the default theme", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    dracula = Expresso.Palette.Builtin.fetch!(:dracula).roles
    default = Expresso.Palette.Builtin.fetch!(:default).roles

    page |> open(render(deck(), tmp_dir))

    assert Enum.map(colors(page), &rgb/1) ==
             Enum.map(
               [dracula.background, dracula.text, dracula.code_background, dracula.code_comment],
               &hex_rgb/1
             )

    emulate(page, "print")

    assert [background, _heading, code, comment] = Enum.map(colors_on_paper(page), &rgb/1)

    assert [background, code, comment] ==
             Enum.map(
               [default.background, default.code_background, default.code_comment],
               &hex_rgb/1
             )
  end

  # On paper the screen does not show, so the colors come from the handout.
  defp colors_on_paper(page) do
    js(page, """
    (() => {
      const color = (selector, property) =>
        getComputedStyle(document.querySelector(selector))[property];
      return [
        color("html", "backgroundColor"),
        color(".handout-page h1", "color"),
        color(".handout-page .highlight", "backgroundColor"),
        color(".handout-page .highlight .c1", "color"),
      ];
    })()
    """)
  end
end
