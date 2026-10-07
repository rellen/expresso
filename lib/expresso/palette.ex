defmodule Expresso.Palette do
  @moduledoc """
  Holds the colors of a theme, and makes sure that they meet the minimums of WCAG and APCA

  A palette has the 16 colors of a base16 scheme, `base00` to `base0F`. The
  scheme gives each color a purpose: `base00` is the background, `base05` the
  text, `base03` the comments, and `base08` to `base0F` the accents. `new/4`
  makes a palette, and it gives each **role** of the theme one of the colors.
  A role is a color that the style sheet reads as a custom property, such as
  `--text` or `--code-keyword`. `roles/0` lists them.

  `problems/1` returns each role that does not meet a minimum. Each minimum has
  two measures: the contrast ratio of WCAG 2.2, and the lightness contrast `Lc`
  of APCA. The contrast ratio is too high for a color on a dark background,
  and APCA corrects this. Thus a color must meet both. These are the minimums:

    * Each role of text, on its background: 4.5:1 and Lc 60. 4.5:1 is the
      minimum of WCAG 2.2 for normal text, criterion 1.4.3. Lc 60 is the
      minimum of APCA for the text of content. A slide shows large text, but a
      projector and the light of a room lower the contrast, so a theme does not
      use the smaller minimums of large text.
    * Each role of text with the dim opacity of the palette, on its
      background: 3:1 and Lc 30. 3:1 is the minimum of criterion 1.4.11 for a
      part that the reader must see. Lc 30 is the minimum of APCA for any
      text that the reader must be able to read, such as a text that the
      presenter does not talk about now. A dimmed element is less important, and it
      must stay readable. The dimming applies to each color of the element,
      such as a comment of a dimmed line of code, so the role with the lowest
      contrast sets the opacity.

  `docs/architecture.md` gives the formulas, and it tells why the dimming of a
  theme is small.

  The accent also colors the progress bar and the frame of the selected page
  in the overview, and 4.5:1 is more than the 3:1 that criterion 1.4.11 gives
  for them. `adjust/1` changes only the lightness of each role that fails,
  until it meets the minimum, and it never changes a background.
  `Expresso.Palette.Builtin` adjusts each built-in theme, and
  `Expresso.ThemeVerifier` gives a warning for a palette of a deck that fails.
  """

  alias Expresso.Color

  @typedoc "A slot of a base16 scheme, from `:base00` to `:base0F`"
  @type slot :: atom()

  @typedoc """
  A palette: its name, its variant, its 16 colors, and the color of each role

  `change` is the largest change of lightness that `adjust/1` made, in OKLab,
  from 0 to 1. `dimmed` holds, for each role of text, its dimmed color and the
  opacity that gives it. `dim_opacity` is one opacity that dims each role of
  text to its minimums. The style sheet dims an image, an SVG file and an
  embed with it, because their colors are not roles.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          variant: :dark | :light,
          colors: %{slot() => Color.t()},
          roles: %{atom() => Color.t()},
          dimmed: %{atom() => {float(), Color.t()}},
          dim_opacity: float(),
          change: float()
        }

  @enforce_keys [:name, :variant, :colors, :roles, :dimmed, :dim_opacity]
  defstruct @enforce_keys ++ [change: 0.0]

  @slots ~w(base00 base01 base02 base03 base04 base05 base06 base07 base08 base09 base0A base0B base0C base0D base0E base0F)a

  # Each role, the slot of its color, and the role of its background. A role of
  # code is on the background of a code block. The two backgrounds have no
  # minimum. The code roles follow the styling guide of base16, with two
  # changes: a variable keeps the color of the text, and no role uses `base0F`.
  @roles [
    background: {:base00, nil},
    text: {:base05, :background},
    muted: {:base04, :background},
    accent: {:base0D, :background},
    warning: {:base09, :background},
    danger: {:base08, :background},
    code_background: {:base01, nil},
    code_text: {:base05, :code_background},
    code_comment: {:base03, :code_background},
    code_tag: {:base08, :code_background},
    code_number: {:base09, :code_background},
    code_type: {:base0A, :code_background},
    code_string: {:base0B, :code_background},
    code_support: {:base0C, :code_background},
    code_function: {:base0D, :code_background},
    code_keyword: {:base0E, :code_background}
  ]

  # The minimums of a role of text on its background: a contrast ratio of WCAG
  # and a lightness contrast of APCA.
  @text_ratio 4.5
  @text_lc 60
  # The minimums of a role of text at the dim opacity.
  @dimmed_ratio 3.0
  @dimmed_lc 30
  # The dim opacity is a multiple of this step, from one step to 1.
  @dim_step 0.05

  @doc "Return the slots of a base16 scheme, in order"
  @spec slots() :: [slot()]
  def slots, do: @slots

  @doc """
  Return each role, the slot of its color, and the role of its background

  A background has `nil` in place of a background.
  """
  @spec roles() :: [{atom(), {slot(), atom() | nil}}]
  def roles, do: @roles

  @doc """
  Make a palette from the 16 colors of a base16 scheme

  `colors` holds a `#rrggbb` color for each slot. Each role of text gets a
  dimmed color: the role blended on its background at the smallest multiple
  of 0.05 that keeps the role at 3:1 and at Lc 30. Each role dims as far as
  its own contrast lets it.
  """
  @spec new(String.t(), :dark | :light, %{slot() => Color.t()}) :: t()
  def new(name, variant, colors) do
    roles = Map.new(@roles, fn {role, {slot, _on}} -> {role, Map.fetch!(colors, slot)} end)

    %__MODULE__{
      name: name,
      variant: variant,
      colors: colors,
      roles: roles,
      dimmed: dimmed(roles),
      dim_opacity: dim_opacity(roles)
    }
  end

  @doc """
  Return each role that does not meet a minimum, with the measure, its value and the minimum

  The measure is `:wcag` for the contrast ratio, or `:apca` for the lightness
  contrast. A role can fail both. The role `:dimmed_text` stands for the role
  of text with the lowest contrast at the dim opacity. A palette that meets
  each minimum returns an empty list.
  """
  @spec problems(t()) :: [{atom(), :wcag | :apca, float(), number()}]
  def problems(%__MODULE__{roles: roles, dim_opacity: opacity}) do
    text =
      for {role, {_slot, on}} <- @roles,
          on != nil,
          problem <- [
            {role, :wcag, Color.contrast(roles[role], roles[on]), @text_ratio},
            {role, :apca, Color.lightness_contrast(roles[role], roles[on]), @text_lc}
          ],
          elem(problem, 2) < elem(problem, 3),
          do: problem

    {ratio, lc} = dimmed_contrast(roles, opacity)

    dimmed =
      for {value, measure, minimum} <- [{ratio, :wcag, @dimmed_ratio}, {lc, :apca, @dimmed_lc}],
          value < minimum,
          do: {:dimmed_text, measure, value, minimum}

    text ++ dimmed
  end

  @doc """
  Return a color that passes for each slot with a role of text that fails

  A slot can color more than one role, such as `base05` for `text` on
  `base00` and for `code_text` on `base01`. The color of the slot changes
  its lightness with `Expresso.Color.adjust/4` against each background in
  turn, and it must then meet the minimums on each one. A slot with no such
  color is not in the map. `Expresso.ThemeVerifier` puts the color into its
  warning.

      iex> colors = Expresso.Palette.Builtin.fetch!(:default).colors
      iex> palette = Expresso.Palette.of(%{colors | base03: "#dddddd"})
      iex> %{base03: color} = Expresso.Palette.suggestions(palette)
      iex> problems = Expresso.Palette.problems(Expresso.Palette.of(%{colors | base03: color}))
      iex> Enum.filter(problems, &(elem(&1, 0) == :code_comment))
      []
  """
  @spec suggestions(t()) :: %{slot() => Color.t()}
  def suggestions(%__MODULE__{colors: colors, roles: roles} = palette) do
    failing = for {role, _measure, _value, _minimum} <- problems(palette), do: role

    for {role, {slot, _on}} <- @roles, role in failing, uniq: true do
      slot
    end
    |> Enum.flat_map(fn slot ->
      backgrounds = for {_role, {^slot, on}} <- @roles, on != nil, do: roles[on]

      case suggestion(colors[slot], backgrounds) do
        {:ok, color} -> [{slot, color}]
        :error -> []
      end
    end)
    |> Map.new()
  end

  defp suggestion(color, backgrounds) do
    adjusted =
      Enum.reduce_while(backgrounds, {:ok, color}, fn background, {:ok, color} ->
        case Color.adjust(color, background, @text_ratio, @text_lc) do
          {:ok, color, _change} -> {:cont, {:ok, color}}
          :error -> {:halt, :error}
        end
      end)

    with {:ok, color} <- adjusted,
         true <- Enum.all?(backgrounds, &meets?(color, &1)) do
      {:ok, color}
    else
      _failure -> :error
    end
  end

  defp meets?(color, background),
    do:
      Color.contrast(color, background) >= @text_ratio and
        Color.lightness_contrast(color, background) >= @text_lc

  @doc """
  Change the lightness of each role that fails, until each role meets its minimum

  The function keeps the hue of each color and each background. It returns
  `:error` when no lightness gives a role its minimum.
  """
  @spec adjust(t()) :: {:ok, t()} | :error
  def adjust(%__MODULE__{roles: roles} = palette) do
    @roles
    |> Enum.reduce_while({%{}, 0.0}, fn
      {role, {_slot, nil}}, {acc, change} ->
        {:cont, {Map.put(acc, role, roles[role]), change}}

      {role, {_slot, on}}, {acc, change} ->
        case Color.adjust(roles[role], roles[on], @text_ratio, @text_lc) do
          {:ok, color, delta} -> {:cont, {Map.put(acc, role, color), max(change, delta)}}
          :error -> {:halt, :error}
        end
    end)
    |> case do
      :error ->
        :error

      {adjusted, change} ->
        {:ok,
         %{
           palette
           | roles: adjusted,
             dimmed: dimmed(adjusted),
             dim_opacity: dim_opacity(adjusted),
             change: change
         }}
    end
  end

  @doc """
  Return the custom properties of the palette, as declarations for a rule

  Each role gets a property, such as `--text`. Each role of text also gets
  the property of its dimmed color, such as `--text-dim`. `--dim-opacity`
  holds the dim opacity of the palette.

      iex> palette = Expresso.Palette.Builtin.fetch!(:default)
      iex> Expresso.Palette.declarations(palette) =~ "--text: #000000;"
      true
      iex> Expresso.Palette.declarations(palette) =~ "--text-dim: #"
      true
  """
  @spec declarations(t()) :: String.t()
  def declarations(%__MODULE__{roles: roles, dimmed: dimmed, dim_opacity: opacity}) do
    colors = for {role, _slot} <- @roles, do: "--#{property(role)}: #{roles[role]};"

    dimmed =
      for {role, _slot} <- @roles,
          Map.has_key?(dimmed, role),
          do: "--#{property(role)}-dim: #{elem(dimmed[role], 1)};"

    Enum.join(colors ++ dimmed ++ ["--dim-opacity: #{opacity};"], " ")
  end

  defp property(role), do: role |> Atom.to_string() |> String.replace("_", "-")

  @typedoc """
  The value of the `theme` option of a deck

  A name of a built-in theme, a map with a color for each slot, or a keyword
  list. The keyword list has `colors` for one theme, or `dark` and `light` for
  two variants, and `adjust` to adjust each map.
  """
  @type theme :: atom() | %{slot() => Color.t()} | keyword()

  @doc """
  Return the palette of one theme of the `theme` option of a deck

  The option is the name of a built-in theme, or a map with a `#rrggbb` color
  for each slot of base16. A palette of a map is not adjusted. Its variant is
  dark when its background is dark. A keyword list returns its first variant
  from `variants/1`.
  """
  @spec of(theme() | nil) :: t()
  def of(nil), do: Expresso.Palette.Builtin.fetch!(:default)
  def of(name) when is_atom(name), do: Expresso.Palette.Builtin.fetch!(name)
  def of(options) when is_list(options), do: options |> variants() |> hd() |> elem(1)

  def of(colors) when is_map(colors) do
    variant = if Color.luminance(colors.base00) < 0.18, do: :dark, else: :light
    new("Custom", variant, colors)
  end

  @doc """
  Return the palette of each variant of the `theme` option of a deck

  A theme with one variant returns `[{nil, palette}]`. A keyword list with
  `dark` and `light` returns `[light: palette, dark: palette]`. With
  `adjust: true`, the palette of each map gets `adjust/1`, as a built-in theme
  does. A map that no lightness can adjust keeps its colors, and
  `Expresso.ThemeVerifier` then gives a warning for each role that fails.

      iex> [{nil, palette}] = Expresso.Palette.variants(:dracula)
      iex> palette.name
      "Dracula"

      iex> Expresso.Palette.variants(dark: :dracula, light: :default) |> Keyword.keys()
      [:light, :dark]
  """
  @spec variants(theme() | nil) :: [{:light | :dark | nil, t()}]
  def variants(options) when is_list(options) do
    adjust = Keyword.get(options, :adjust, false)

    case Keyword.fetch(options, :colors) do
      {:ok, colors} ->
        [{nil, scheme(colors, adjust)}]

      :error ->
        [light: scheme(options[:light], adjust), dark: scheme(options[:dark], adjust)]
    end
  end

  def variants(theme), do: [{nil, of(theme)}]

  defp scheme(colors, true) when is_map(colors) do
    palette = of(colors)

    case adjust(palette) do
      {:ok, adjusted} -> adjusted
      :error -> palette
    end
  end

  defp scheme(theme, _adjust), do: of(theme)

  @doc """
  Validate the value of the `theme` option, for the schema of the DSL

  The value is the name of a built-in theme, or a map with exactly the 16
  slots of base16 and a `#rrggbb` color for each one. The contrast is not part
  of the validation: `Expresso.ThemeVerifier` gives a warning for it.

  The value can also be a keyword list:

    * `colors` with a name or a map, for one theme, or
    * `dark` and `light`, each with a name or a map, for two variants,
    * and `adjust` with `true` or `false`, optional.

      iex> Expresso.Palette.validate(dark: :dracula, light: :default, adjust: true)
      {:ok, [dark: :dracula, light: :default, adjust: true]}

      iex> {:error, message} = Expresso.Palette.validate(dark: :dracula)
      iex> message =~ "needs colors, or both dark and light"
      true

      iex> Expresso.Palette.validate(:dracula)
      {:ok, :dracula}

      iex> {:error, message} = Expresso.Palette.validate(:plaid)
      iex> message =~ "is not a built-in theme"
      true
  """
  @spec validate(term()) :: {:ok, theme()} | {:error, String.t()}
  def validate([_ | _] = options) do
    keys = if Keyword.keyword?(options), do: Keyword.keys(options), else: nil

    cond do
      keys == nil ->
        validate(nil)

      keys != Enum.uniq(keys) ->
        {:error, "the theme has a key two times"}

      keys -- [:colors, :dark, :light, :adjust] != [] ->
        {:error,
         "the theme takes the keys colors, dark, light and adjust, not " <>
           inspect(keys -- [:colors, :dark, :light, :adjust])}

      not one_form?(keys) ->
        {:error, "the theme needs colors, or both dark and light, and not both forms"}

      not is_boolean(Keyword.get(options, :adjust, false)) ->
        {:error, "the adjust key of the theme takes true or false"}

      true ->
        options
        |> Enum.map(fn
          {:adjust, adjust} -> {:ok, {:adjust, adjust}}
          {key, value} -> one(value) |> Shoddy.Result.map_ok(&{key, &1})
        end)
        |> Shoddy.Result.collect()
    end
  end

  def validate(value), do: one(value)

  # One theme with `colors`, or two variants with `dark` and `light`.
  defp one_form?(keys) do
    variants = Enum.count(keys, &(&1 in [:dark, :light]))
    if :colors in keys, do: variants == 0, else: variants == 2
  end

  defp one(name) when is_atom(name) and name != nil do
    if name in Expresso.Palette.Builtin.names(),
      do: {:ok, name},
      else:
        {:error,
         "#{inspect(name)} is not a built-in theme. The built-in themes are #{Enum.map_join(Expresso.Palette.Builtin.names(), ", ", &inspect/1)}"}
  end

  defp one(colors) when is_map(colors) do
    missing = @slots -- Map.keys(colors)
    extra = Map.keys(colors) -- @slots
    bad = for {slot, color} <- colors, slot in @slots, not hex?(color), do: slot

    cond do
      missing != [] -> {:error, "the theme has no color for #{inspect(missing)}"}
      extra != [] -> {:error, "the theme has the unknown slots #{inspect(extra)}"}
      bad != [] -> {:error, "the colors of #{inspect(bad)} are not #rrggbb"}
      true -> {:ok, Map.new(colors, fn {slot, color} -> {slot, String.downcase(color)} end)}
    end
  end

  defp one(value),
    do:
      {:error,
       "the theme must be the name of a built-in theme, a map of 16 colors or a keyword list, not #{inspect(value)}"}

  defp hex?(color), do: is_binary(color) and Regex.match?(~r/\A#[0-9a-fA-F]{6}\z/, color)

  # The dimmed color of each role of text, with its opacity: the role blended
  # on its background at the smallest step that keeps the role at its minimums
  # for a dimmed element. A role under the minimums gets no dimming.
  defp dimmed(roles) do
    steps = round(1 / @dim_step)

    for {role, {_slot, on}} <- @roles, on != nil, into: %{} do
      step =
        Enum.find(1..steps, steps, fn step ->
          dimmed_meets?(Color.blend(roles[role], roles[on], step / steps), roles[on])
        end)

      opacity = step / steps
      {role, {opacity, Color.blend(roles[role], roles[on], opacity)}}
    end
  end

  defp dimmed_meets?(color, background) do
    Color.contrast(color, background) >= @dimmed_ratio and
      Color.lightness_contrast(color, background) >= @dimmed_lc
  end

  # The smallest multiple of 0.05 that keeps each dimmed role of text at its
  # minimums. A palette with a role under them gets no dimming.
  defp dim_opacity(roles) do
    steps = round(1 / @dim_step)

    Enum.find(1..steps, steps, fn step ->
      {ratio, lc} = dimmed_contrast(roles, step / steps)
      ratio >= @dimmed_ratio and lc >= @dimmed_lc
    end) / steps
  end

  # The lowest contrast ratio and the lowest lightness contrast of the roles of
  # text on their backgrounds, with the opacity. The two can come from
  # different roles.
  defp dimmed_contrast(roles, opacity) do
    dimmed =
      for {role, {_slot, on}} <- @roles, on != nil do
        color = Color.blend(roles[role], roles[on], opacity)
        {Color.contrast(color, roles[on]), Color.lightness_contrast(color, roles[on])}
      end

    {dimmed |> Enum.map(&elem(&1, 0)) |> Enum.min(),
     dimmed |> Enum.map(&elem(&1, 1)) |> Enum.min()}
  end
end
