defmodule Expresso.Css do
  @moduledoc """
  The CSS of a deck, and the names in a style sheet

  The `css` option of a deck holds a style sheet, or the path of a file that
  holds one. `resolve/1` gives the style sheet. The renderer puts it into the
  document after the theme and after the generated rules, so a rule of the
  deck can replace each rule of the theme.

  `scan/1` gives the names of a style sheet that the compiler checks: the
  custom properties that it uses, declares and registers, and the effects
  that it gives a rule. `Expresso.Theme` scans the theme in the same way, and
  the verifiers join the two results.
  """

  @typedoc "The names of a style sheet"
  @type names :: %{
          used: MapSet.t(String.t()),
          declared: MapSet.t(String.t()),
          registered: %{String.t() => String.t()},
          effects: MapSet.t(String.t())
        }

  @doc """
  Give the style sheet of a `css` option

  A value with a brace or a line break is a style sheet. A different value is
  the path of a file, relative to the working directory of the command, as the
  path of an image is. `nil` gives an empty style sheet.
  """
  @spec resolve(String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def resolve(nil), do: {:ok, ""}

  def resolve(css) when is_binary(css) do
    if inline?(css), do: {:ok, css}, else: read(css)
  end

  @doc """
  Tell whether a `css` option is a style sheet, and not a path
  """
  @spec inline?(String.t()) :: boolean()
  def inline?(css), do: String.contains?(css, ["{", "\n"])

  # The path comes from the deck, and `Code.eval_file/1` runs the deck.
  # sobelow_skip ["Traversal.FileModule"]
  defp read(path) do
    case File.read(path) do
      {:ok, css} -> {:ok, css}
      {:error, reason} -> {:error, "cannot read the CSS file \"#{path}\": #{reason}"}
    end
  end

  @doc """
  Make a style sheet safe for a `style` element

  The text `</` can close the `style` element. The function writes `<\\/`,
  which CSS reads as the same two characters in a string, a comment or a URL.
  """
  @spec escape(String.t()) :: String.t()
  def escape(css), do: String.replace(css, "</", "<\\/")

  @doc """
  Give the names of a style sheet

  - `used` holds each name after two hyphens. CSS reads a custom property
    with `var()` only, and it writes one in a declaration or in an
    `@property` rule. Each of the three forms holds the name after two
    hyphens.
  - `declared` holds each custom property that the style sheet gives a value
    that is not a number, such as `--dur: 300ms`.
  - `registered` gives the `syntax` descriptor of each `@property` rule.
  - `effects` holds each effect with a rule for `[data-effect="..."]`, with
    underscores, as the deck writes the atom. The names stay strings, because
    a style sheet of a deck must not make atoms.
  """
  @spec scan(String.t()) :: names()
  def scan(css) do
    %{
      used: used(css),
      declared: declared(css),
      registered: registered(css),
      effects: effects(css)
    }
  end

  @doc """
  Join the names of two style sheets
  """
  @spec merge(names(), names()) :: names()
  def merge(a, b) do
    %{
      used: MapSet.union(a.used, b.used),
      declared: MapSet.union(a.declared, b.declared),
      registered: Map.merge(a.registered, b.registered),
      effects: MapSet.union(a.effects, b.effects)
    }
  end

  defp used(css) do
    ~r/--([\w-]+)/ |> Regex.scan(css, capture: :all_but_first) |> List.flatten() |> MapSet.new()
  end

  # A number, such as `--alert: 0`, stays valid for a state, so this set does
  # not hold it. The name of an `@property` rule comes before a brace, and not
  # before a colon, so this set holds the declarations only.
  defp declared(css) do
    for [name, value] <-
          Regex.scan(~r/--([\w-]+)\s*:\s*([^;}]*)/, css, capture: :all_but_first),
        not Regex.match?(~r/^-?\d+(\.\d+)?$/, String.trim(value)),
        into: MapSet.new(),
        do: name
  end

  # A rule without a `syntax` descriptor is not valid, and the browser ignores
  # it.
  defp registered(css) do
    for [name, body] <-
          Regex.scan(~r/@property\s+--([\w-]+)\s*\{([^}]*)\}/, css, capture: :all_but_first),
        descriptor = Regex.run(~r/syntax:\s*"([^"]*)"/, body, capture: :all_but_first),
        into: %{},
        do: {name, hd(descriptor)}
  end

  defp effects(css) do
    for [name] <- Regex.scan(~r/\[data-effect="([\w-]+)"\]/, css, capture: :all_but_first),
        into: MapSet.new(),
        do: String.replace(name, "-", "_")
  end
end
