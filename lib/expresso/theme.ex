defmodule Expresso.Theme do
  @moduledoc """
  The custom properties, the effects and the transitions of the theme

  `assets/style.css` is the theme of this project, and the theme owns the
  custom properties. This module reads the file at compile time with
  `Expresso.Css.scan/1`, and it gives four answers. `uses?/1` tells you
  whether the theme uses a property. `declares?/1` tells you whether the theme
  gives the property a value. `syntax/1` gives the `syntax` descriptor of the
  `@property` rule of the theme. `effects/0` gives the effects of the theme,
  and `transitions/0` gives its transitions between slides.

  `Expresso.Overlay.Properties` reads the answers, and
  `Expresso.Overlay.PropertyVerifier` then gives a warning for a property that
  the theme does not use. The CSS of a deck adds its own names.
  `docs/overlays.md` gives the contract.
  """

  @external_resource "./assets/style.css"

  @names "./assets/style.css" |> File.read!() |> Expresso.Css.scan()

  @doc """
  Give the names of the theme, for `Expresso.Css.merge/2`

  The fade has no rule, because each element with steps fades. The function
  adds it to the effects. The browser fades from one slide to the next
  without a rule, and the kind `none` has no animation, so the function adds
  the two to the transitions.
  """
  @spec names() :: Expresso.Css.names()
  def names do
    %{
      @names
      | effects: MapSet.put(@names.effects, "fade"),
        transitions: MapSet.union(@names.transitions, MapSet.new(["fade", "none"]))
    }
  end

  @doc """
  Tell whether the theme uses the custom property of a name

  The name comes from the `state` option or from a key of the `set` option of
  an `on` entity.
  """
  @spec uses?(atom()) :: boolean()
  def uses?(name), do: Atom.to_string(name) in @names.used

  @doc """
  Tell whether the theme gives the custom property of a name a value that is
  not a number

  The compiler registers each state as a number with the initial value 0. That
  registration makes a value of a different type invalid, and the property then
  falls back to 0. A number stays valid. Therefore a state must not take the
  name of a property that the theme gives a value of a different type.
  """
  @spec declares?(atom()) :: boolean()
  def declares?(name), do: Atom.to_string(name) in @names.declared

  @doc """
  Give the `syntax` descriptor of the `@property` rule of the theme

  The function gives `nil` for a property that the theme does not register.
  """
  @spec syntax(atom()) :: String.t() | nil
  def syntax(name), do: Map.get(@names.registered, Atom.to_string(name))

  @doc """
  Give the effects of the theme, with the fade
  """
  @spec effects() :: MapSet.t(String.t())
  def effects, do: names().effects

  @doc """
  Give the transitions of the theme, with the fade and the kind `none`
  """
  @spec transitions() :: MapSet.t(String.t())
  def transitions, do: names().transitions
end
