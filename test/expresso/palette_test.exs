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

  test "the dim opacity is the strongest dimming that keeps the text at 3:1" do
    for name <- Builtin.names(),
        %Palette{roles: roles, dim_opacity: opacity} = Builtin.fetch!(name) do
      dimmed =
        Color.contrast(Color.blend(roles.text, roles.background, opacity), roles.background)

      assert dimmed >= 3.0, "#{name}"

      if opacity > 0.05 do
        stronger = Color.blend(roles.text, roles.background, opacity - 0.05)
        assert Color.contrast(stronger, roles.background) < 3.0, "#{name}"
      end
    end
  end

  test "problems names each role under its minimum, and the dimmed text" do
    palette = Palette.of(colors(%{base03: "#eeeeee", base05: "#aaaaaa"}))

    roles = for {role, _ratio, _minimum} <- Palette.problems(palette), do: role
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

    assert text =~ "--dim-opacity: 0.4;"
  end
end
