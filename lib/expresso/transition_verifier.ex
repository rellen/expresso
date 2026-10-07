defmodule Expresso.TransitionVerifier do
  @moduledoc """
  The Spark verifier of the transitions between slides

  It runs one time for each deck module at compile time. It makes sure that
  the `transition` option of the deck and of each slide has a rule. The theme
  gives the rules of `:slide` and `:zoom`, and the fade and `:none` need no
  rule. The CSS of the deck can give more, such as
  `html[data-transition="wipe-down"]::view-transition-new(slide)` for
  `transition :wipe_down`.

  `Expresso.Overlay.EffectVerifier` reports a `css` option that it cannot
  read, so this verifier then checks the deck with the theme alone.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Theme
  alias Spark.Dsl.Verifier

  @doc """
  Make sure that each transition of the deck has a rule
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    transitions =
      case dsl_state |> Verifier.get_option([:deck], :css) |> Expresso.Css.resolve() do
        {:ok, css} -> MapSet.union(Theme.transitions(), Expresso.Css.scan(css).transitions)
        {:error, _reported_by_effect_verifier} -> Theme.transitions()
      end

    slides =
      for slide <- Verifier.get_entities(dsl_state, [:deck]),
          do: {slide.transition, [:deck, :slide] ++ List.wrap(slide.name)}

    [{Verifier.get_option(dsl_state, [:deck], :transition), [:deck]} | slides]
    |> Enum.find(fn {transition, _path} -> without_rule?(transition, transitions) end)
    |> case do
      nil -> :ok
      {transition, path} -> {:error, error(module, path, message(transition))}
    end
  end

  defp without_rule?(nil, _transitions), do: false
  defp without_rule?(transition, transitions), do: Atom.to_string(transition) not in transitions

  defp message(transition) do
    name = Expresso.Steps.kind(transition)

    "the transition #{inspect(transition)} has no rule in the theme or in the CSS of the deck. " <>
      ~s|Give it a rule for html[data-transition="#{name}"]::view-transition-new(slide) | <>
      "in the css option of the deck"
  end

  defp error(module, path, message) do
    Spark.Error.DslError.exception(module: module, message: message, path: path)
  end
end
