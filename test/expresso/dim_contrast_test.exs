defmodule Expresso.DimContrastTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.{Builder, Color, Palette}

  doctest Expresso.Deck, only: [dim_contrast: 1]
  doctest Expresso.Palette, only: [with_dim_contrast: 2]

  # The custom properties of the first `:root` rule of the theme of a document.
  defp properties(opts) do
    style =
      []
      |> one_slide([], opts)
      |> document()
      |> LazyHTML.query("style")
      |> Enum.map_join("\n", &LazyHTML.text/1)

    [_, rule] = Regex.run(~r/:root \{ (--background[^}]*) \}/, style)

    for [_, name, value] <- Regex.scan(~r/--([a-z0-9-]+): ([^;]+);/, rule),
        into: %{},
        do: {name, String.trim(value)}
  end

  # Each dimmed role of text, with the contrast of its dimmed color on its
  # background.
  defp dimmed_contrasts(properties) do
    for {role, {_slot, on}} <- Palette.roles(), on != nil do
      name = role |> Atom.to_string() |> String.replace("_", "-")
      background = Map.fetch!(properties, on |> Atom.to_string() |> String.replace("_", "-"))
      {role, Color.contrast(Map.fetch!(properties, name <> "-dim"), background)}
    end
  end

  test "with 4.5, each dimmed role of text keeps 4.5:1 on its background" do
    for {role, contrast} <- dimmed_contrasts(properties(dim_contrast: 4.5)) do
      assert contrast >= 4.5, "#{role} has #{contrast}:1"
    end
  end

  test "without the option, the dimming stays at 3:1, as before" do
    default = properties([])
    assert default == properties(dim_contrast: 3)

    assert Enum.any?(dimmed_contrasts(default), fn {_role, contrast} -> contrast < 4.5 end)
  end

  test "a higher minimum dims less" do
    palette = Palette.Builtin.fetch!(:dracula)
    strict = Palette.with_dim_contrast(palette, 4.5)

    assert strict.dim_ratio == 4.5
    assert strict.dim_opacity > palette.dim_opacity
    assert Palette.problems(strict) == []
  end

  test "each variant of a theme with two variants dims to the minimum" do
    style =
      []
      |> one_slide([],
        theme: [light: :solarized_light, dark: :solarized_dark],
        dim_contrast: 4.5
      )
      |> Expresso.Deck.render()

    assert [_, _ | _] = Regex.scan(~r/--text-dim: (#[0-9a-f]{6})/, style)
  end

  test "the compiler refuses a value outside 3 to 7" do
    for value <- [2, 7.5, "4.5", :aa] do
      assert_raise ArgumentError, ~r/from 3 to 7/, fn ->
        Builder.deck([], name: "x", dim_contrast: value)
      end
    end
  end

  test "the DSL takes it" do
    defmodule StrictDeck do
      use Expresso

      dim_contrast 4.5

      slide "start" do
        heading "Contrast"
      end
    end

    assert {:ok, deck} = Expresso.to_deck(StrictDeck)
    assert deck.metadata.dim_contrast == 4.5
  end
end
