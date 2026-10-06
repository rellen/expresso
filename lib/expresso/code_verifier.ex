defmodule Expresso.CodeVerifier do
  @moduledoc """
  The Spark verifier of the language of each code element

  It runs one time for each deck module at compile time. A code element with
  a language that no lexer registers shows its lines with no colors, so a
  misspelled name, such as `"elixr"`, gives no visible error. The verifier
  gives a warning for such a language, with the list of the languages that
  `Expresso.Highlight.languages/0` returns. The deck still compiles, and the
  element shows plain text. A code element with no language gets no warning.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Element.Code
  alias Expresso.Highlight
  alias Expresso.Slide
  alias Spark.Dsl.{Entity, Verifier}

  @typedoc "A warning of the verifier, with the location of the code element"
  @type warning :: {String.t(), :erl_anno.anno()} | String.t()

  @doc """
  Give a warning for each code element of the deck with a language that no lexer registers
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:warn, [warning()]}
  def verify(dsl_state) do
    languages = Highlight.languages()

    warnings =
      dsl_state
      |> Verifier.get_entities([:deck])
      |> Enum.flat_map(&slide(&1, languages))

    if warnings == [], do: :ok, else: {:warn, warnings}
  end

  defp slide(%Slide{} = slide, languages) do
    path = Enum.join([:deck, :slide | List.wrap(slide.name)], " -> ")

    slide.elements
    |> List.wrap()
    |> codes()
    |> Enum.reject(&(is_nil(&1.lang) or &1.lang in languages))
    |> Enum.map(&warning(&1, path, languages))
  end

  defp slide(_entity, _languages), do: []

  defp codes(elements) do
    Enum.flat_map(elements, fn
      %Code{} = code -> [code]
      %{elements: children} when is_list(children) -> codes(children)
      _element -> []
    end)
  end

  defp warning(%Code{lang: lang} = code, path, languages) do
    text =
      "#{path}: no lexer registers the language #{inspect(lang)}, so the code element " <>
        "shows its lines with no colors. The languages with a lexer are: " <>
        Enum.join(languages, ", ")

    case Entity.anno(code) do
      nil -> text
      anno -> {text, anno}
    end
  end
end
