defmodule Expresso.Overlay.Check do
  @moduledoc """
  The checks of the overlay steps of one slide

  `slide/1` does the work of the verifier, and it is a pure function on an
  `Expresso.Slide` struct that `Expresso.Overlay.Expand.slide/1` expanded. It
  reads the `steps` field of each element and of each `on` entity.

  `docs/overlays.md` gives the conditions.
  """

  alias Expresso.Element.{On, Pause}
  alias Expresso.Slide

  @doc """
  Give an error for a slide that breaks a rule of the overlays

  The function reports the first of these conditions:

  - A `pause` entity is inside an element.
  - A step number is less than 1.
  - An `on` entity has a step at which its element does not show.
  - A child element has a step at which its parent does not show.

  An element without an `at` option shows at each step of its parent, and the
  function accepts each step for it. The transformer reports a step that is
  more than the maximum, because the expansion needs the maximum.
  """
  @spec slide(Slide.t()) :: :ok | {:error, String.t()}
  def slide(%Slide{elements: elements}) do
    check_all(elements || [], nil, false)
  end

  defp check_all(elements, parent, nested?) do
    Enum.reduce_while(elements, :ok, fn element, :ok ->
      case check(element, parent, nested?) do
        :ok -> {:cont, :ok}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp check(%Pause{}, _parent, false), do: :ok

  defp check(%Pause{}, parent, true) do
    {:error,
     "a pause entity is inside a #{name(parent)}, and a pause goes at the level of the slide"}
  end

  defp check(element, parent, _nested?) do
    steps = Map.get(element, :steps)

    with :ok <- check_positive(steps, name(element)),
         :ok <- check_inside(steps, parent, "the #{name(element)}"),
         :ok <- check_on(Map.get(element, :on) || [], element),
         do: check_all(Map.get(element, :elements) || [], element, true)
  end

  defp check_on(on, element) do
    Enum.reduce_while(on, :ok, fn %On{steps: steps}, :ok ->
      with :ok <- check_positive(steps, "on entity"),
           :ok <- check_inside(steps, element, "the on entity") do
        {:cont, :ok}
      else
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp check_positive(nil, _name), do: :ok

  defp check_positive(steps, name) do
    case Enum.find(steps, &(&1 < 1)) do
      nil -> :ok
      step -> {:error, "the #{name} has the step #{step}, and a step is 1 or more"}
    end
  end

  # An element without steps shows at each step of its parent. A parent
  # without steps shows at each step. Neither gives an error.
  defp check_inside(nil, _parent, _name), do: :ok
  defp check_inside(_steps, nil, _name), do: :ok

  defp check_inside(steps, parent, name) do
    with parent_steps when is_list(parent_steps) <- Map.get(parent, :steps),
         step when is_integer(step) <- Enum.find(steps, &(&1 not in parent_steps)) do
      {:error, "#{name} has the step #{step}, and the #{name(parent)} does not show at that step"}
    else
      nil -> :ok
    end
  end

  defp name(%module{}) do
    module |> Module.split() |> List.last() |> Macro.underscore()
  end
end
