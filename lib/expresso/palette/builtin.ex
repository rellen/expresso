defmodule Expresso.Palette.Builtin do
  @moduledoc """
  Holds the built-in themes, each one adjusted to the minimums of `Expresso.Palette`

  `assets/themes/` holds the base16 schemes of the Tinted Theming project,
  unchanged, and `assets/themes/LICENSE` gives their license. This module reads
  each file when it compiles, and `Expresso.Palette.adjust/1` changes the
  lightness of each color that fails a minimum. The name of a theme is the
  name of its file, such as `:catppuccin_mocha` for `catppuccin-mocha.yaml`.

  A theme is built in only when no color of its adjusted roles moves more than
  0.4 in the lightness of OKLab, which is two fifths of the way from black to
  white. A larger change gives a color that the reader does not know as a color
  of the scheme. The compile stops for a file that needs a larger change. The
  comments of a dark scheme need the largest change, because most schemes give
  them a low contrast. A comment has little chroma, so it stays a gray of the
  scheme.
  `docs/reference/theme-option.md` lists the themes, and the schemes that this
  limit leaves out.

  The theme `:default` is the theme of Expresso. It has black text on white,
  and its code colors come from the Tango style of Makeup.
  """

  alias Expresso.Palette

  @limit 0.4

  @directory "assets/themes"

  @default Palette.new("Default", :light, %{
             base00: "#ffffff",
             base01: "#f8f8f8",
             base02: "#e6e6e6",
             base03: "#8f5902",
             base04: "#595959",
             base05: "#000000",
             base06: "#000000",
             base07: "#000000",
             base08: "#a40000",
             base09: "#ce5c00",
             base0A: "#000000",
             base0B: "#4e9a06",
             base0C: "#204a87",
             base0D: "#3465a4",
             base0E: "#204a87",
             base0F: "#5c35cc"
           })

  @files @directory |> Path.join("*.yaml") |> Path.wildcard() |> Enum.sort()

  for file <- @files, do: @external_resource(file)
  @external_resource @directory

  # The palette of a scheme file. The file is YAML, and this module reads only
  # its `name`, its `variant` and the 16 colors of its `palette`.
  read = fn file ->
    text = File.read!(file)
    [_all, name] = Regex.run(~r/^name:\s*"([^"]+)"/m, text)
    [_all, variant] = Regex.run(~r/^variant:\s*"(dark|light)"/m, text)

    colors =
      for [_all, slot, hex] <- Regex.scan(~r/^\s+(base0[0-9A-F]):\s*"#?([0-9a-fA-F]{6})"/m, text),
          into: %{},
          do: {String.to_atom(slot), "#" <> String.downcase(hex)}

    if map_size(colors) != 16, do: raise("#{file} does not hold the 16 colors of base16")

    key = file |> Path.basename(".yaml") |> String.replace("-", "_") |> String.to_atom()
    {key, Palette.new(name, String.to_atom(variant), colors)}
  end

  limit = @limit

  adjusted = fn {key, palette}, file ->
    case Palette.adjust(palette) do
      {:ok, %Palette{change: change} = adjusted} when change <= limit ->
        {key, adjusted}

      {:ok, %Palette{change: change}} ->
        raise "#{file} needs a change of lightness of #{Float.round(change, 3)}, more than #{limit}"

      :error ->
        raise "#{file} cannot meet the minimums of Expresso.Palette"
    end
  end

  {:ok, default} = Palette.adjust(@default)

  @palettes Map.new([{:default, default} | Enum.map(@files, &adjusted.(read.(&1), &1))])

  @doc "Return the names of the built-in themes, in alphabetical order"
  @spec names() :: [atom()]
  def names, do: @palettes |> Map.keys() |> Enum.sort()

  @doc """
  Return the adjusted palette of a built-in theme

      iex> Expresso.Palette.Builtin.fetch!(:dracula).name
      "Dracula"
  """
  @spec fetch!(atom()) :: Palette.t()
  def fetch!(name), do: Map.fetch!(@palettes, name)

  @doc "Return the largest change of lightness that a built-in theme may need"
  @spec limit() :: float()
  def limit, do: @limit
end
