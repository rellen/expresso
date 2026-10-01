defmodule Expresso.Palette do
  @moduledoc """
  Holds the colors of a theme, and makes sure that they meet the minimums of WCAG

  A palette has the 16 colors of a base16 scheme, `base00` to `base0F`. The
  scheme gives each color a purpose: `base00` is the background, `base05` the
  text, `base03` the comments, and `base08` to `base0F` the accents. `new/4`
  makes a palette, and it gives each **role** of the theme one of the colors.
  A role is a color that the style sheet reads as a custom property, such as
  `--text` or `--code-keyword`. `roles/0` lists them.

  `problems/1` returns each role that does not meet its minimum. These are the
  minimums:

    * Each role of text, on its background: 4.5:1. This is the minimum of WCAG
      2.2 for normal text, criterion 1.4.3. A slide shows large text, but a
      projector and the light of a room lower the contrast, so a theme does not
      use the smaller minimum of large text.
    * The text with the dim opacity of the palette, on the background: 3:1,
      which criterion 1.4.11 gives for a part that the reader must see. A dimmed
      element is less important, and it must stay readable.

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
  from 0 to 1. `dim_opacity` is the opacity of a dimmed element.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          variant: :dark | :light,
          colors: %{slot() => Color.t()},
          roles: %{atom() => Color.t()},
          dim_opacity: float(),
          change: float()
        }

  @enforce_keys [:name, :variant, :colors, :roles, :dim_opacity]
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

  @text 4.5
  @dimmed 3.0

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

  `colors` holds a `#rrggbb` color for each slot. The dim opacity is the
  smallest multiple of 0.05 that keeps dimmed text at 3:1 on the background.
  """
  @spec new(String.t(), :dark | :light, %{slot() => Color.t()}) :: t()
  def new(name, variant, colors) do
    roles = Map.new(@roles, fn {role, {slot, _on}} -> {role, Map.fetch!(colors, slot)} end)

    %__MODULE__{
      name: name,
      variant: variant,
      colors: colors,
      roles: roles,
      dim_opacity: dim_opacity(roles)
    }
  end

  @doc """
  Return each role that does not meet its minimum, with its contrast and the minimum

  A palette that meets each minimum returns an empty list.
  """
  @spec problems(t()) :: [{atom(), float(), float()}]
  def problems(%__MODULE__{roles: roles, dim_opacity: opacity}) do
    text =
      for {role, {_slot, on}} <- @roles,
          on != nil,
          ratio = Color.contrast(roles[role], roles[on]),
          ratio < @text,
          do: {role, ratio, @text}

    dimmed = Color.contrast(Color.blend(roles.text, roles.background, opacity), roles.background)
    if dimmed < @dimmed, do: text ++ [{:dimmed_text, dimmed, @dimmed}], else: text
  end

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
        case Color.adjust(roles[role], roles[on], @text) do
          {:ok, color, delta} -> {:cont, {Map.put(acc, role, color), max(change, delta)}}
          :error -> {:halt, :error}
        end
    end)
    |> case do
      :error ->
        :error

      {adjusted, change} ->
        {:ok, %{palette | roles: adjusted, dim_opacity: dim_opacity(adjusted), change: change}}
    end
  end

  @doc """
  Return the custom properties of the palette, as declarations for a rule

      iex> palette = Expresso.Palette.Builtin.fetch!(:default)
      iex> Expresso.Palette.declarations(palette) =~ "--text: #000000;"
      true
  """
  @spec declarations(t()) :: String.t()
  def declarations(%__MODULE__{roles: roles, dim_opacity: opacity}) do
    colors =
      for {role, _slot} <- @roles,
          do: "--#{role |> Atom.to_string() |> String.replace("_", "-")}: #{roles[role]};"

    Enum.join(colors ++ ["--dim-opacity: #{opacity};"], " ")
  end

  @doc """
  Return the palette of the `theme` option of a deck

  The option is the name of a built-in theme, or a map with a `#rrggbb` color
  for each slot of base16. A palette of a map is not adjusted. Its variant is
  dark when its background is dark.
  """
  @spec of(atom() | %{slot() => Color.t()} | nil) :: t()
  def of(nil), do: Expresso.Palette.Builtin.fetch!(:default)
  def of(name) when is_atom(name), do: Expresso.Palette.Builtin.fetch!(name)

  def of(colors) when is_map(colors) do
    variant = if Color.luminance(colors.base00) < 0.18, do: :dark, else: :light
    new("Custom", variant, colors)
  end

  @doc """
  Validate the value of the `theme` option, for the schema of the DSL

  The value is the name of a built-in theme, or a map with exactly the 16
  slots of base16 and a `#rrggbb` color for each one. The contrast is not part
  of the validation: `Expresso.ThemeVerifier` gives a warning for it.

      iex> Expresso.Palette.validate(:dracula)
      {:ok, :dracula}

      iex> {:error, message} = Expresso.Palette.validate(:plaid)
      iex> message =~ "is not a built-in theme"
      true
  """
  @spec validate(term()) :: {:ok, atom() | map()} | {:error, String.t()}
  def validate(name) when is_atom(name) do
    if name in Expresso.Palette.Builtin.names(),
      do: {:ok, name},
      else:
        {:error,
         "#{inspect(name)} is not a built-in theme. The built-in themes are #{Enum.map_join(Expresso.Palette.Builtin.names(), ", ", &inspect/1)}"}
  end

  def validate(colors) when is_map(colors) do
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

  def validate(value),
    do:
      {:error,
       "the theme must be the name of a built-in theme or a map of 16 colors, not #{inspect(value)}"}

  defp hex?(color), do: is_binary(color) and Regex.match?(~r/\A#[0-9a-fA-F]{6}\z/, color)

  # The smallest multiple of 0.05 that keeps dimmed text at 3:1. Text that
  # fails the minimum itself gets no dimming.
  defp dim_opacity(roles) do
    Enum.find(1..20, 20, fn step ->
      dimmed = Color.blend(roles.text, roles.background, step / 20)
      Color.contrast(dimmed, roles.background) >= @dimmed
    end) / 20
  end
end
