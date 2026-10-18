defmodule Expresso.Overlay.Check do
  @moduledoc """
  The checks of the overlay steps of one slide

  `slide/1` does the work of the verifier, and it is a pure function on an
  `Expresso.Slide` struct that `Expresso.Overlay.Expand.slide/1` expanded. It
  reads the `steps` field of each element and of each `on` entity.

  `docs/overlays.md` gives the conditions.
  """

  alias Expresso.Element.{Focus, On, Part, Pause}
  alias Expresso.Slide
  alias Shoddy.Result

  @doc """
  Give an error for a slide that breaks a rule of the overlays

  The function reports the first of these conditions:

  - A `pause` entity is inside an element.
  - A step number is less than 1.
  - An `on` entity has a step at which its element does not show.
  - An `on` entity with `move_to` is not in a part of a diagram, or it also
    sets `x` or `y`.
  - A child element has a step at which its nearest ancestor with steps does
    not show.
  - A group of the `highlight` option of a chart has a step at which the chart
    does not show.
  - A frame of a chart starts at a step at which the chart does not show.

  An element without an `at` option shows at each step of its parent.
  Therefore its nearest ancestor with steps limits the steps of its
  descendants and of its `on` entities. An element without such an ancestor
  shows at each step, and the function accepts each step for it. The transformer reports a step that is
  more than the maximum, because the expansion needs the maximum.
  """
  @spec slide(Slide.t()) :: :ok | {:error, String.t()}
  def slide(%Slide{elements: elements}) do
    check_all(elements || [], nil, nil)
  end

  # The parent is the direct parent of the elements, and it is nil at the
  # level of the slide. The limit is the nearest ancestor with steps, or nil.
  defp check_all(elements, parent, limit) do
    elements
    |> Stream.map(&check(&1, parent, limit))
    |> Result.collect()
    |> Result.ignore()
  end

  defp check(%Pause{}, nil, _limit), do: :ok

  defp check(%Pause{}, parent, _limit) do
    {:error,
     "a pause entity is inside a #{name(parent)}, and a pause goes at the level of the slide"}
  end

  defp check(element, _parent, limit) do
    steps = Map.get(element, :steps)
    inner = if steps, do: element, else: limit

    with :ok <- check_positive(steps, name(element)),
         :ok <- check_inside(steps, limit, "the #{name(element)}"),
         :ok <- check_on(Map.get(element, :on) || [], element, inner),
         :ok <- check_frames(Map.get(element, :timeline) || [], inner),
         :ok <- check_all(Map.get(element, :focus) || [], element, inner),
         do: check_all(Expresso.Element.Tree.children(element), element, inner)
  end

  defp check_on(on, element, limit) do
    on
    |> Stream.map(fn %On{steps: steps} = entity ->
      with :ok <- check_positive(steps, "on entity"),
           :ok <- check_move(entity, element),
           do: check_inside(steps, limit, "the on entity")
    end)
    |> Result.collect()
    |> Result.ignore()
  end

  # A frame shows from its first step to the step before the next frame, or
  # to the last step of the slide. Only the first step must be a step of the
  # chart, because the last frame can show after the chart.
  defp check_frames(frames, limit) do
    frames
    |> Stream.map(fn
      %{steps: [first | _]} -> check_inside([first], limit, "a frame of the chart")
      _frame -> :ok
    end)
    |> Result.collect()
    |> Result.ignore()
  end

  defp check_move(%On{move_to: nil}, _element), do: :ok

  defp check_move(%On{}, element) when not is_struct(element, Part),
    do:
      {:error,
       "the on entity of the #{name(element)} has move_to, and only an on entity of a part takes it"}

  defp check_move(%On{set: set}, _element) do
    if Keyword.has_key?(set || [], :x) or Keyword.has_key?(set || [], :y),
      do:
        {:error, "an on entity with move_to gives x and y itself, so its set has no x and no y"},
      else: :ok
  end

  defp check_positive(nil, _name), do: :ok

  defp check_positive(steps, name) do
    case Enum.find(steps, &(&1 < 1)) do
      nil -> :ok
      step -> {:error, "the #{name} has the step #{step}, and a step is 1 or more"}
    end
  end

  # An element without steps shows at each step of its limit. Without a
  # limit, it shows at each step. Neither gives an error.
  defp check_inside(nil, _limit, _name), do: :ok
  defp check_inside(_steps, nil, _name), do: :ok

  defp check_inside(steps, limit, name) do
    case Enum.find(steps, &(&1 not in limit.steps)) do
      nil ->
        :ok

      step ->
        {:error,
         "#{name} has the step #{step}, and the #{name(limit)} does not show at that step"}
    end
  end

  defp name(%Focus{}), do: "group of the highlight option"

  defp name(%module{}) do
    module |> Module.split() |> List.last() |> Macro.underscore()
  end
end
