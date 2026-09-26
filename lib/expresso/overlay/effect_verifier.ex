defmodule Expresso.Overlay.EffectVerifier do
  @moduledoc """
  The Spark verifier of the `css` option and of the effects

  It runs one time for each deck module at compile time. It reads the `css`
  option of the deck with `Expresso.Css.resolve/1`, and a file that it cannot
  read is an error. It then makes sure that each effect of the deck, of a
  slide and of an element has a rule. The theme gives the rules of the effects
  of this project, and the CSS of the deck can give more, such as
  `[data-effect="spin"]` for `effect :spin`. The fade needs no rule.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Element.Pause
  alias Expresso.Theme
  alias Spark.Dsl.Verifier

  @doc """
  Check the CSS of the deck and each effect of the deck
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    case dsl_state |> Verifier.get_option([:deck], :css) |> Expresso.Css.resolve() do
      {:ok, css} ->
        effects = MapSet.union(Theme.effects(), Expresso.Css.scan(css).effects)
        check_deck(dsl_state, module, effects)

      {:error, message} ->
        {:error, error(module, [:deck, :css], message)}
    end
  end

  defp check_deck(dsl_state, module, effects) do
    with :ok <-
           check([Verifier.get_option(dsl_state, [:deck], :effect)], effects, module, [:deck]) do
      dsl_state
      |> Verifier.get_entities([:deck])
      |> Enum.reduce_while(:ok, &check_slide(&1, &2, effects, module))
    end
  end

  defp check_slide(slide, :ok, effects, module) do
    path = [:deck, :slide] ++ List.wrap(slide.name)

    case check([slide.effect | element_effects(slide.elements || [])], effects, module, path) do
      :ok -> {:cont, :ok}
      error -> {:halt, error}
    end
  end

  defp check(values, effects, module, path) do
    case Enum.find(values, &without_rule?(&1, effects)) do
      nil -> :ok
      effect -> {:error, error(module, path, message(effect))}
    end
  end

  defp without_rule?(nil, _effects), do: false
  defp without_rule?(effect, effects), do: Atom.to_string(effect) not in effects

  defp element_effects(elements) do
    Enum.flat_map(elements, fn
      %Pause{} -> []
      element -> [Map.get(element, :effect) | element_effects(Map.get(element, :elements) || [])]
    end)
  end

  defp message(effect) do
    name = effect |> Atom.to_string() |> String.replace("_", "-")

    "the effect #{inspect(effect)} has no rule in the theme or in the CSS of the deck. " <>
      ~s(Give it a rule for [data-effect="#{name}"] in the css option of the deck)
  end

  defp error(module, path, message) do
    Spark.Error.DslError.exception(module: module, message: message, path: path)
  end
end
