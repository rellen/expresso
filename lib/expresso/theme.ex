defmodule Expresso.Theme do
  @moduledoc """
  The custom properties of the theme

  `assets/style.css` is the theme of this project, and the theme owns the
  custom properties. This module reads the file at compile time, and it gives
  three answers about one name. `uses?/1` tells you whether the theme uses the
  property. `declares?/1` tells you whether the theme gives the property a
  value. `syntax/1` gives the `syntax` descriptor of the `@property` rule of
  the theme.

  `Expresso.Overlay.Properties` reads both answers, and
  `Expresso.Overlay.PropertyVerifier` then gives a warning for a property that
  the theme does not use. `docs/overlays.md` gives the contract.
  """

  @external_resource "./assets/style.css"

  @css File.read!("./assets/style.css")

  # Each name after two hyphens in the theme. CSS reads a custom property with
  # `var()` only, and it writes one in a declaration or in an `@property` rule.
  # Each of the three forms holds the name after two hyphens. Therefore each
  # name in the file is a name that the theme uses.
  @used ~r/--([\w-]+)/ |> Regex.scan(@css, capture: :all_but_first) |> List.flatten()

  # The `syntax` descriptor of each property that the theme registers. A rule
  # without a `syntax` descriptor is not valid, and the browser ignores it.
  @registered for [name, body] <-
                    Regex.scan(~r/@property\s+--([\w-]+)\s*\{([^}]*)\}/, @css,
                      capture: :all_but_first
                    ),
                  descriptor = Regex.run(~r/syntax:\s*"([^"]*)"/, body, capture: :all_but_first),
                  into: %{},
                  do: {name, hd(descriptor)}

  @doc """
  Tell whether the theme uses the custom property of a name

  The name comes from the `state` option or from a key of the `set` option of
  an `on` entity.
  """
  @spec uses?(atom()) :: boolean()
  def uses?(name), do: Atom.to_string(name) in @used

  # Each name that the theme gives a value of a type that is not a number, such
  # as `--dur: 300ms`. A registration as a number makes such a value invalid.
  # A number, such as `--alert: 0`, stays valid, so this list does not hold it.
  # The name of an `@property` rule comes before a brace, and not before a
  # colon, so this list holds the declarations only.
  @declared for [name, value] <-
                  Regex.scan(~r/--([\w-]+)\s*:\s*([^;}]*)/, @css, capture: :all_but_first),
                not Regex.match?(~r/^-?\d+(\.\d+)?$/, String.trim(value)),
                uniq: true,
                do: name

  @doc """
  Tell whether the theme gives the custom property of a name a value that is
  not a number

  The compiler registers each state as a number with the initial value 0. That
  registration makes a value of a different type invalid, and the property then
  falls back to 0. A number stays valid. Therefore a state must not take the
  name of a property that the theme gives a value of a different type.
  """
  @spec declares?(atom()) :: boolean()
  def declares?(name), do: Atom.to_string(name) in @declared

  @doc """
  Give the `syntax` descriptor of the `@property` rule of the theme

  The function gives `nil` for a property that the theme does not register.
  """
  @spec syntax(atom()) :: String.t() | nil
  def syntax(name), do: Map.get(@registered, Atom.to_string(name))
end
