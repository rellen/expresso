defmodule Expresso.DimGraphicOpacityTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Expresso.Test.HTML

  alias Expresso.{Builder, ThemeVerifier}

  doctest Expresso.Deck, only: [dim_graphic_opacity: 1]

  # The text of each `style` element of the document of a deck with one slide.
  defp style(opts) do
    []
    |> one_slide([], opts)
    |> document()
    |> LazyHTML.query("style")
    |> Enum.map_join("\n", &LazyHTML.text/1)
  end

  # Each value that a rule of the document gives to `--dim-graphic-opacity`.
  defp opacities(style),
    do: ~r/--dim-graphic-opacity: ([^;]+);/ |> Regex.scan(style) |> Enum.map(&List.last/1)

  test "a deck with the option gives --dim-graphic-opacity to each variant and to paper" do
    style = style(dim_graphic_opacity: 0.5)

    assert opacities(style) == ["0.5"]
    assert style =~ "\n:root { --dim-graphic-opacity: 0.5; }"
  end

  test "a deck without the option gives no --dim-graphic-opacity, so a graphic dims as before" do
    style = style([])

    assert opacities(style) == []
    assert style =~ "var(--dim-graphic-opacity, var(--dim-opacity))"
  end

  # Issue #358: at 4.5, a light built-in theme has `--dim-opacity` 1.0, so a
  # graphic does not dim. The option gives the graphic its own opacity.
  test "a light theme at a dim contrast of 4.5 keeps --dim-opacity 1.0 and dims a graphic to the option" do
    capture_io(:stderr, fn ->
      style = style(theme: :default, dim_contrast: 4.5, dim_graphic_opacity: 0.4)

      assert style =~ "--dim-opacity: 1.0;"
      assert opacities(style) == ["0.4"]
    end)
  end

  test "the warning of a theme that does not dim names only the roles of text with the option" do
    assert [without] = ThemeVerifier.dim_messages(:default, 4.5)
    assert without =~ "a dimmed image, SVG file, embed and video do not dim"
    assert without =~ "or give dim_graphic_opacity for the graphics"

    assert [with] = ThemeVerifier.dim_messages(:default, 4.5, 0.5)
    refute with =~ "image"
    refute with =~ "dim_graphic_opacity"

    assert with =~
             "so the roles warning, success, argument, code_number, code_string, code_support do not dim."
  end

  test "the compiler gives the shorter warning for a deck with the option" do
    warning =
      capture_io(:stderr, fn ->
        Builder.deck([], name: "x", dim_contrast: 4.5, dim_graphic_opacity: 0.5)
      end)

    assert warning =~ "the theme gives --dim-opacity 1.0, so the roles"
    refute warning =~ "image"
  end

  test "the compiler refuses a value that is not more than 0 and not more than 1" do
    for value <- [0, -0.5, 1.5, "0.5", :half] do
      assert_raise ArgumentError, ~r/more than 0 and not more than 1/, fn ->
        Builder.deck([], name: "x", dim_graphic_opacity: value)
      end
    end
  end

  test "the DSL takes it" do
    defmodule GraphicDeck do
      use Expresso

      theme :dracula
      dim_graphic_opacity(0.5)

      slide "s" do
        heading "A slide"
      end
    end

    {:ok, deck} = Expresso.to_deck(GraphicDeck)
    assert deck.metadata.dim_graphic_opacity == 0.5
    assert Expresso.Deck.render(deck) =~ ":root { --dim-graphic-opacity: 0.5; }"
  end
end
