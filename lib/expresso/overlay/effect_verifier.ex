defmodule Expresso.Overlay.EffectVerifier do
  @moduledoc """
  The Spark verifier of the `css` option and of the effects

  It runs one time for each deck module at compile time. It reads the names
  of the `css` option from `Expresso.Dsl.css_names/1`, and a file that
  `Expresso.CssTransformer` cannot read is an error. It then makes sure that
  each effect of the deck, of a slide and of an element has a rule. The theme
  gives the rules of the effects of this project, and the CSS of the deck can
  give more, such as `[data-effect="spin"]` for `effect :spin`. The fade needs
  no rule.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Dsl
  alias Expresso.Element.Tree
  alias Expresso.Theme
  alias Shoddy.Result
  alias Spark.Dsl.Verifier

  @doc """
  Check the CSS of the deck and each effect of the deck
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    case Dsl.css_names(dsl_state) do
      {:ok, names} -> check_deck(dsl_state, module, MapSet.union(Theme.effects(), names.effects))
      {:error, message} -> {:error, Dsl.error(module, [:deck, :css], message)}
    end
  end

  defp check_deck(dsl_state, module, effects) do
    deck = check([Verifier.get_option(dsl_state, [:deck], :effect)], effects)

    with :ok <- Result.map_error(deck, &Dsl.error(module, [:deck], &1)) do
      dsl_state |> Dsl.map_slides(&check_slide(&1, effects)) |> Result.ignore()
    end
  end

  defp check_slide(slide, effects) do
    values = slide.elements |> Tree.descendants() |> Enum.map(&Map.get(&1, :effect))
    check([slide.effect | values], effects)
  end

  defp check(values, effects) do
    case Enum.find(values, &without_rule?(&1, effects)) do
      nil -> :ok
      effect -> {:error, message(effect)}
    end
  end

  defp without_rule?(nil, _effects), do: false
  defp without_rule?(effect, effects), do: Atom.to_string(effect) not in effects

  defp message(effect) do
    name = effect |> Atom.to_string() |> String.replace("_", "-")

    "the effect #{inspect(effect)} has no rule in the theme or in the CSS of the deck. " <>
      ~s(Give it a rule for [data-effect="#{name}"] in the css option of the deck)
  end
end
