defmodule Expresso.PaletteTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Expresso.{Color, Palette}
  alias Expresso.Palette.Builtin

  doctest Expresso.Palette
  doctest Expresso.Palette.Builtin

  defp colors(overrides \\ %{}) do
    Builtin.fetch!(:default).colors |> Map.merge(overrides)
  end

  # Whether each role of text meets 3:1 and Lc 30 on its background, with the
  # opacity.
  defp dimmed?(roles, opacity) do
    Enum.all?(Palette.roles(), fn
      {_role, {_slot, nil}} ->
        true

      {role, {_slot, on}} ->
        color = Color.blend(roles[role], roles[on], opacity)

        Color.contrast(color, roles[on]) >= 3.0 and
          Color.lightness_contrast(color, roles[on]) >= 30
    end)
  end

  test "each built-in theme meets each minimum, within the limit of the change" do
    for name <- Builtin.names(), palette = Builtin.fetch!(name) do
      assert Palette.problems(palette) == [], "#{name}"
      assert palette.change <= Builtin.limit(), "#{name}"
    end
  end

  test "the built-in themes are the default theme and each file of assets/themes" do
    files =
      for file <- Path.wildcard("assets/themes/*.yaml"),
          do: file |> Path.basename(".yaml") |> String.replace("-", "_") |> String.to_atom()

    assert Builtin.names() == Enum.sort([:default | files])
  end

  test "the adjustment keeps each background and the hue of each color" do
    palette = Builtin.fetch!(:dracula)

    assert palette.roles.background == "#282a36"
    assert palette.roles.code_background == "#21222c"
    assert palette.roles.text == "#f8f8f2"
    assert palette.colors.base03 == "#6272a4"
    refute palette.roles.code_comment == "#6272a4"
    assert Color.contrast(palette.roles.code_comment, palette.roles.code_background) >= 4.5
  end

  test "the dim opacity is the strongest dimming that keeps each role of text at 3:1 and Lc 30" do
    for name <- Builtin.names(),
        %Palette{roles: roles, dim_opacity: opacity} = Builtin.fetch!(name) do
      assert dimmed?(roles, opacity), "#{name}"

      if opacity > 0.05 do
        refute dimmed?(roles, opacity - 0.05), "#{name}"
      end
    end
  end

  test "each dimmed color is the strongest dimming of its role that keeps 3:1 and Lc 30" do
    for name <- Builtin.names(),
        %Palette{roles: roles, dimmed: dimmed} = Builtin.fetch!(name),
        {role, {_slot, on}} <- Palette.roles(),
        on != nil do
      {opacity, color} = Map.fetch!(dimmed, role)
      background = roles[on]

      assert color == Color.blend(roles[role], background, opacity), "#{name} #{role}"
      assert Color.contrast(color, background) >= 3.0, "#{name} #{role}"
      assert Color.lightness_contrast(color, background) >= 30, "#{name} #{role}"

      if opacity > 0.05 do
        stronger = Color.blend(roles[role], background, opacity - 0.05)

        refute Color.contrast(stronger, background) >= 3.0 and
                 Color.lightness_contrast(stronger, background) >= 30,
               "#{name} #{role}"
      end
    end
  end

  test "the text of a theme dims further than the shared dim opacity" do
    %Palette{dimmed: dimmed, dim_opacity: shared} = Builtin.fetch!(:dracula)

    assert {0.45, _color} = dimmed.text
    assert shared == 0.65
  end

  test "the declarations write the dimmed color of each role of text, and none for a background" do
    palette = Builtin.fetch!(:dracula)
    text = Palette.declarations(palette)

    assert text =~ "--text-dim: #{elem(palette.dimmed.text, 1)};"
    assert text =~ "--code-comment-dim: #{elem(palette.dimmed.code_comment, 1)};"
    refute text =~ "--background-dim"
    refute text =~ "--code-background-dim"
  end

  test "each role of text of a built-in theme meets Lc 60 on its background" do
    for name <- Builtin.names(),
        %Palette{roles: roles} = Builtin.fetch!(name),
        {role, {_slot, on}} <- Palette.roles(),
        on != nil do
      assert Color.lightness_contrast(roles[role], roles[on]) >= 60, "#{name} #{role}"
    end
  end

  test "the APCA minimum makes a comment of a dark theme lighter than the WCAG minimum does" do
    # The comments of Dracula are at 4.5:1 after a change for WCAG alone, and
    # at Lc 37. The APCA minimum asks for Lc 60.
    %Palette{roles: roles} = Builtin.fetch!(:dracula)

    assert Color.contrast(roles.code_comment, roles.code_background) > 6.0
    assert Color.lightness_contrast(roles.code_comment, roles.code_background) >= 60
  end

  test "a dimmed comment of the theme of the Line 4 example stays at 3:1 and Lc 30" do
    palette =
      Palette.of(%{
        base00: "#1b232c",
        base01: "#222c37",
        base02: "#33404d",
        base03: "#acbac8",
        base04: "#acbac8",
        base05: "#e6ebf0",
        base06: "#f0f4f7",
        base07: "#ffffff",
        base08: "#fe9e99",
        base09: "#ffb13b",
        base0A: "#f0d12a",
        base0B: "#5cf58a",
        base0C: "#9dc4d6",
        base0D: "#e8b83a",
        base0E: "#8fbafe",
        base0F: "#c8a061"
      })

    %Palette{roles: roles, dim_opacity: opacity} = palette

    comment = Color.blend(roles.code_comment, roles.code_background, opacity)
    assert Color.contrast(comment, roles.code_background) >= 3.0
    assert Color.lightness_contrast(comment, roles.code_background) >= 30
    assert Palette.problems(palette) == []
  end

  test "problems names each role under its minimum, and the dimmed text" do
    palette = Palette.of(colors(%{base03: "#eeeeee", base05: "#aaaaaa"}))

    roles = for {role, _measure, _value, _minimum} <- Palette.problems(palette), do: role
    assert :code_comment in roles
    assert :text in roles
    assert :dimmed_text in roles
  end

  property "adjust gives each palette with a dark or a light background its minimums" do
    check all background <- member_of(["#101010", "#202a36", "#fafafa", "#fdf6e3"]),
              accents <- list_of(integer(0..0xFFFFFF), length: 14),
              max_runs: 100 do
      slots = Palette.slots() -- [:base00, :base01]
      hex = &("#" <> String.pad_leading(String.downcase(Integer.to_string(&1, 16)), 6, "0"))
      colors = Map.new(Enum.zip(slots, Enum.map(accents, hex)))

      palette =
        Palette.new("Random", :dark, Map.merge(colors, %{base00: background, base01: background}))

      assert {:ok, adjusted} = Palette.adjust(palette)
      assert Palette.problems(adjusted) == []
    end
  end

  test "suggestions gives each slot of a failing role a color that passes on each background of the slot" do
    palette = Palette.of(colors(%{base05: "#999999", base09: "#ffaa00"}))
    suggestions = Palette.suggestions(palette)

    assert Map.keys(suggestions) |> Enum.sort() == [:base05, :base09, :base0B]

    fixed = Palette.of(colors(suggestions))
    failing = fixed |> Palette.problems() |> Enum.map(&elem(&1, 0))

    for {role, {slot, _on}} <- Palette.roles(),
        Map.has_key?(suggestions, slot),
        do: refute(role in failing, inspect(role))
  end

  test "suggestions leaves out a slot with no lightness that passes, and a palette that passes" do
    assert Palette.suggestions(Palette.of(colors(%{base00: "#808080", base01: "#808080"}))) == %{}
    assert Palette.suggestions(Builtin.fetch!(:dracula)) == %{}
  end

  describe "the keyword form of the theme" do
    # A dark scheme that fails 15 checks, from the guide to colors of your own.
    @harbor %{
      base00: "#13233a",
      base01: "#1b2f4b",
      base02: "#27405f",
      base03: "#4f6a8a",
      base04: "#8fa3bc",
      base05: "#dfe7f1",
      base06: "#eef3f9",
      base07: "#ffffff",
      base08: "#e0605a",
      base09: "#e8964a",
      base0A: "#e6c45c",
      base0B: "#7cbf6e",
      base0C: "#5fbfbf",
      base0D: "#5c9ce6",
      base0E: "#b48ae6",
      base0F: "#c47a5a"
    }

    test "validate takes colors, or dark and light, with adjust" do
      assert Palette.validate(colors: @harbor, adjust: true) ==
               {:ok, [colors: @harbor, adjust: true]}

      assert Palette.validate(dark: @harbor, light: :default) ==
               {:ok, [dark: @harbor, light: :default]}
    end

    test "validate refuses a wrong key, a key two times, a missing variant, both forms and a bad value" do
      for {value, text} <- [
            {[colour: @harbor], "takes the keys colors, dark, light and adjust"},
            {[colors: :default, colors: :dracula], "a key two times"},
            {[dark: :dracula], "needs colors, or both dark and light"},
            {[colors: :default, dark: :dracula], "needs colors, or both dark and light"},
            {[colors: :default, adjust: "yes"], "takes true or false"},
            {[dark: :plaid, light: :default], "is not a built-in theme"}
          ] do
        assert {:error, message} = Palette.validate(value), inspect(value)
        assert message =~ text, inspect(value)
      end
    end

    test "variants adjusts a map with adjust true, and keeps it without" do
      assert [{nil, kept}] = Palette.variants(colors: @harbor)
      assert length(Palette.problems(kept)) == 15

      assert [{nil, adjusted}] = Palette.variants(colors: @harbor, adjust: true)
      assert Palette.problems(adjusted) == []
      assert adjusted.roles.background == @harbor.base00
    end

    test "variants gives the light variant first, and adjust applies to each map" do
      assert [light: light, dark: dark] =
               Palette.variants(dark: @harbor, light: :default, adjust: true)

      assert light == Builtin.fetch!(:default)
      assert Palette.problems(dark) == []
      assert Palette.of(dark: @harbor, light: :default) == light
    end

    test "a map that no lightness can adjust keeps its colors" do
      gray = Map.merge(@harbor, %{base00: "#808080", base01: "#808080"})

      assert [{nil, palette}] = Palette.variants(colors: gray, adjust: true)
      assert palette.roles == Palette.of(gray).roles
    end
  end

  test "of reads a built-in name, a map, or the default for nil" do
    assert Palette.of(nil) == Builtin.fetch!(:default)
    assert Palette.of(:zenburn).name == "Zenburn"
    assert %Palette{name: "Custom", variant: :light} = Palette.of(colors())
    assert %Palette{variant: :dark} = Palette.of(Builtin.fetch!(:dracula).colors)
  end

  test "validate refuses a map without each slot, with another slot, or with a color that is not #rrggbb" do
    assert {:ok, _colors} = Palette.validate(colors(%{base00: "#FFFFFF"}))

    assert {:error, "the theme has no color for [:base0F]"} =
             Palette.validate(Map.delete(colors(), :base0F))

    assert {:error, "the theme has the unknown slots [:base10]"} =
             Palette.validate(colors(%{base10: "#000000"}))

    assert {:error, "the colors of [:base00] are not #rrggbb"} =
             Palette.validate(colors(%{base00: "white"}))

    assert {:error, _message} = Palette.validate("dracula")
  end

  test "the declarations name each role and the dim opacity" do
    text = Palette.declarations(Builtin.fetch!(:dracula))

    for {role, _slot} <- Palette.roles() do
      assert text =~ "--#{role |> Atom.to_string() |> String.replace("_", "-")}: #"
    end

    assert text =~ "--dim-opacity: 0.65;"
  end
end
