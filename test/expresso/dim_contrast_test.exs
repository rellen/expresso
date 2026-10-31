defmodule Expresso.DimContrastTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.{Builder, Color, Palette}

  doctest Expresso.Deck, only: [dim_contrast: 1]
  doctest Expresso.Palette, only: [with_dim_contrast: 2]
  doctest Expresso.ThemeVerifier

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

  # Each light built-in theme has a role near 4.5:1, so it does not dim at 4.5
  # and it gives a warning. The tests at 4.5 use a dark theme, or a lower ratio.
  test "with 4.5, each dimmed role of text keeps 4.5:1 on its background" do
    for {role, contrast} <- dimmed_contrasts(properties(theme: :dracula, dim_contrast: 4.5)) do
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
        dim_contrast: 4
      )
      |> Expresso.Deck.render()

    assert [_, _ | _] = Regex.scan(~r/--text-dim: (#[0-9a-f]{6})/, style)
  end

  describe "a theme that does not dim at the minimum" do
    alias Expresso.ThemeVerifier

    test "gives a warning that names --dim-opacity and each role that does not dim" do
      assert [message] = ThemeVerifier.dim_messages(:default, 4.5)

      assert message =~ "at a dim contrast of 4.5:1, the theme gives --dim-opacity 1.0"
      assert message =~ "a dimmed image, SVG file, embed and video do not dim"

      assert message =~
               "the roles warning, success, argument, code_number, code_string, code_support do not dim"
    end

    test "the reference gives the warning for the default theme" do
      [example] =
        Regex.run(~r/```text\n(.*)\n```/, File.read!("docs/reference/dim-contrast-option.md"),
          capture: :all_but_first
        )

      assert ThemeVerifier.dim_messages(:default, 4.5) == [example]
    end

    test "names one role that does not dim in the singular" do
      # Tokyo Night Light with the slot of the accent in place of base0C, so
      # only the role warning does not dim.
      [{_name, palette}] = Expresso.Palette.variants(:tokyo_night_light)
      colors = Map.put(palette.colors, :base0C, palette.colors.base0D)
      assert [message] = ThemeVerifier.dim_messages([colors: colors, adjust: true], 4.5)
      assert message =~ "and the role warning does not dim."
    end

    test "says that no role of text dims when each role keeps its color" do
      assert [message] = ThemeVerifier.dim_messages(:solarized_light, 4.5)
      assert message =~ "no role of text dims"
    end

    test "gives a warning for each light built-in theme, because each has --dim-opacity 1.0 at 4.5" do
      for name <- [
            :default,
            :github,
            :one_light,
            :rose_pine_dawn,
            :solarized_light,
            :tokyo_night_light
          ] do
        assert [_] = ThemeVerifier.dim_messages(name, 4.5), "#{name} has no warning"
        assert Palette.with_dim_contrast(Palette.Builtin.fetch!(name), 4.5).dim_opacity == 1.0
      end
    end

    test "gives no warning for a theme that dims" do
      assert ThemeVerifier.dim_messages(:dracula, 4.5) == []

      for name <- Palette.Builtin.names(),
          do: assert(ThemeVerifier.dim_messages(name, nil) == [], "#{name} has a warning at 3")
    end

    test "names the variant of a theme with two variants" do
      assert [message] = ThemeVerifier.dim_messages([light: :github, dark: :dracula], 4.5)
      assert message =~ "the light theme gives --dim-opacity 1.0"
    end
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

      theme :dracula
      dim_contrast 4.5

      slide "start" do
        heading "Contrast"
      end
    end

    assert {:ok, deck} = Expresso.to_deck(StrictDeck)
    assert deck.metadata.dim_contrast == 4.5
  end
end
