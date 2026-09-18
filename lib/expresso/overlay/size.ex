defmodule Expresso.Overlay.Size do
  @moduledoc """
  The check of the number of steps of one slide

  `slide/1` is a pure function on an `Expresso.Slide` struct that
  `Expresso.Overlay.Expand.slide/1` expanded. It gives a warning for a slide
  with very many steps, because such a slide usually comes from a mistake in a
  step number.

  `docs/overlays.md` gives the rule.
  """

  alias Expresso.Slide
  alias Spark.Dsl.Entity

  # A slide of more than this number of steps is not usual. A deck of the
  # repository has 5 steps at most, and a slide with more steps than this
  # number usually comes from a step number with a mistake, such as `at 1000`.
  @maximum 50

  @typedoc "A warning of the verifier, with the location of the slide"
  @type warning :: {String.t(), :erl_anno.anno()} | String.t()

  @doc """
  Give the number of steps that a slide can take with no warning
  """
  @spec maximum() :: pos_integer()
  def maximum, do: @maximum

  @doc """
  Give a warning for a slide with very many steps

  The function gives no warning for a slide with a `steps` option, because
  that option is a statement of the author. It gives a warning for a maximum
  that comes from a specification only.

  The renderer writes one rule for each step of the deck, and one handout page
  for each step of each slide. Therefore a step number with a mistake, such as
  `at 1000`, makes a document of many pages and of many rules.
  """
  @spec slide(Slide.t()) :: [warning()]
  def slide(%Slide{steps: steps}) when is_integer(steps), do: []

  def slide(%Slide{} = slide) do
    max = (slide.metadata || %{})[:max_step] || 1

    if max > @maximum do
      path = Enum.join([:deck, :slide | List.wrap(slide.name)], " -> ")

      message(
        "#{path}: the slide takes #{max} steps, and #{@maximum} is the usual maximum. " <>
          "A step number of a specification gives this number. The document then holds " <>
          "#{max} handout pages for the slide. Give the slide a `steps` option for no warning.",
        slide
      )
    else
      []
    end
  end

  defp message(text, slide) do
    case Entity.anno(slide) do
      nil -> [text]
      anno -> [{text, anno}]
    end
  end
end
