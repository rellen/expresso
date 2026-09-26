defmodule Expresso.Overlay.Expand do
  @moduledoc """
  The expansion of the overlay specifications of one slide

  `slide/1` does the work of the transformer, and it is a pure function on an
  `Expresso.Slide` struct. It reads the elements in document order, it gives
  each `:next` the value of the counter, it removes each `pause` from the
  slide, and it expands each specification into a list of step numbers. The
  maximum step number goes into the metadata of the slide.

  `docs/overlays.md` gives the rules.
  """

  alias Expresso.Element.{On, Pause}
  alias Expresso.Overlay
  alias Expresso.Slide

  @doc """
  Expand the specifications of a slide

  The counter of the slide starts at 1. A `pause` at the level of the slide
  increments the counter, and the function removes it. Inside an element, the
  `at` option reads the counter first, then each `on` entity in order, then
  each child element. A `pause` inside an element stays in place, and the
  verifier reports it.

  The maximum step number is the `steps` option of the slide when the slide
  declares it. Otherwise it is the largest step number of the specifications,
  or 1 when no specification has a step number. The function writes the
  maximum into `metadata.max_step`, and it puts the step numbers of each
  specification into the `steps` field of the element or of the `on` entity.
  An element without an `at` option keeps `nil` in that field.

  The `auto_reveal` option of the slide gives an implicit `[from: :next]` to
  each element at the level of the slide that has no `at` option. The function
  applies the option before the counter walk. It changes no nested element,
  and a nested element without an `at` option keeps `nil`.

  The `reveal` option of an element, such as a `list` or a `table`, gives the
  same implicit specification to each child of the element that has no `at`
  option. With a `header` option, the first child keeps `nil`. A code element
  holds a list in the option, and `Expresso.Element.Code.build/1` makes its
  children with the specification before this function runs. The children of
  an element with an absolute `at` option read a counter that starts at the
  first step of the element, and the counter of the slide does not change.
  Therefore the children show one after the other from the first step of the
  element, and no child gets a step at which the element does not show.

  The `dim` option of a list, a table or a code element gives each child the
  state `dim` from the first step of a later child. The function adds an `on`
  entity with the state after the expansion, with the steps of the child from
  that step. A child without steps does not dim.

  The function gives an error when a specification has a step number that is
  more than the maximum. It gives the same error for a step of the `handout`
  option of the slide. That option does not change the maximum.
  """
  @spec slide(Slide.t()) :: {:ok, Slide.t()} | {:error, String.t()}
  def slide(%Slide{} = slide) do
    elements = auto_reveal(slide.elements || [], slide.auto_reveal)
    {elements, _counter} = resolve(elements, 1)
    max = slide.steps || max_step(elements) || 1

    with {:ok, elements} <- expand(elements, max),
         {:ok, _steps} <- handout(slide.handout, max) do
      metadata = Map.put(slide.metadata || %{}, :max_step, max)
      {:ok, %Slide{slide | elements: elements, metadata: metadata}}
    end
  end

  # The handout option can name a step only after the maximum is known. A step
  # that the slide does not have is an error, as it is for an element.
  defp handout(nil, _max), do: {:ok, []}
  defp handout(handout, max), do: Expresso.Handout.pages(handout, max)

  # The implicit specification of the auto_reveal option. It goes on each
  # element at the level of the slide that has no at option. A pause has no at
  # field, so the first clause does not match it.

  defp auto_reveal(elements, true) do
    Enum.map(elements, fn
      %{at: nil} = element -> %{element | at: Overlay.from_next()}
      element -> element
    end)
  end

  defp auto_reveal(elements, _auto_reveal), do: elements

  # The counter walk at the level of the slide

  defp resolve([], counter), do: {[], counter}

  defp resolve([%Pause{} | rest], counter), do: resolve(rest, counter + 1)

  defp resolve([element | rest], counter) do
    {element, counter} = resolve_element(element, counter)
    {rest, counter} = resolve(rest, counter)
    {[element | rest], counter}
  end

  # The counter walk inside an element

  defp resolve_element(%Pause{} = pause, counter), do: {pause, counter}

  defp resolve_element(element, counter) do
    spec = at(element)
    {at, counter} = resolve_spec(spec, counter)

    {on, counter} =
      Enum.map_reduce(on(element), counter, fn %On{} = on, counter ->
        {at, counter} = resolve_spec(on.at, counter)
        {%On{on | at: at}, counter}
      end)

    children = reveal(element)

    {children, counter} =
      if reveals?(element) and absolute?(spec) do
        {children, _local} =
          Enum.map_reduce(children, Overlay.first_step(spec), &resolve_element/2)

        {children, counter}
      else
        Enum.map_reduce(children, counter, &resolve_element/2)
      end

    {put(element, at, on, children), counter}
  end

  # The implicit specification of the reveal option. It goes on each child of
  # the element that has no at option. The header of a table is the first
  # child, and it keeps nil.

  defp reveal(%{reveal: true} = element) do
    children = children(element)

    {header, rest} =
      if Map.get(element, :header) == true, do: Enum.split(children, 1), else: {[], children}

    header ++ auto_reveal(rest, true)
  end

  defp reveal(element), do: children(element)

  # A list or a table has the value true, and a code element has a list of
  # line groups. Either reveals its children.
  defp reveals?(element) do
    case Map.get(element, :reveal) do
      true -> true
      [_ | _] -> true
      _other -> false
    end
  end

  defp absolute?(nil), do: false
  defp absolute?(%Overlay{} = spec), do: not Overlay.relative?(spec)

  defp resolve_spec(nil, counter), do: {nil, counter}
  defp resolve_spec(%Overlay{} = spec, counter), do: Overlay.resolve_next(spec, counter)

  # The largest explicit step number of the elements

  defp max_step(elements) do
    elements
    |> Enum.flat_map(&specs/1)
    |> Enum.map(&Overlay.max_step/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
  end

  defp specs(%Pause{}), do: []

  defp specs(element) do
    at = List.wrap(at(element))
    on = Enum.map(on(element), & &1.at)
    at ++ on ++ Enum.flat_map(children(element), &specs/1)
  end

  # The expansion into step numbers

  defp expand(elements, max) do
    Enum.reduce_while(elements, {:ok, []}, fn element, {:ok, acc} ->
      case expand_element(element, max) do
        {:ok, element} -> {:cont, {:ok, [element | acc]}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
    |> case do
      {:ok, elements} -> {:ok, Enum.reverse(elements)}
      {:error, message} -> {:error, message}
    end
  end

  defp expand_element(%Pause{} = pause, _max), do: {:ok, pause}

  defp expand_element(element, max) do
    with {:ok, steps} <- expand_spec(at(element), max),
         {:ok, on} <- expand_on(on(element), max),
         {:ok, children} <- expand(children(element), max) do
      element = put(element, at(element), on, dim(element, children))
      {:ok, %{element | steps: steps}}
    end
  end

  # The dim option. A child dims from the first step of a later child, which
  # is the smallest first step that is more than its own first step. The state
  # applies only at the steps of the child, so the child shows at each step of
  # its on entity. A child without steps never dims, and a later child does
  # not wait for it. The on entity goes after the on entities of the child.

  defp dim(%{dim: true}, children) do
    firsts = for %{steps: [first | _]} <- children, uniq: true, do: first

    Enum.map(children, fn
      %{steps: [first | _] = steps} = child ->
        case Enum.filter(firsts, &(&1 > first)) do
          [] -> child
          later -> dim_child(child, steps, Enum.min(later))
        end

      child ->
        child
    end)
  end

  defp dim(_element, children), do: children

  defp dim_child(child, steps, from) do
    case Enum.filter(steps, &(&1 >= from)) do
      [] ->
        child

      steps ->
        {:ok, at} = Overlay.new(steps)
        %{child | on: on(child) ++ [%On{at: at, state: :dim, steps: steps}]}
    end
  end

  defp expand_on(on, max) do
    Enum.reduce_while(on, {:ok, []}, fn %On{} = on, {:ok, acc} ->
      case expand_spec(on.at, max) do
        {:ok, steps} -> {:cont, {:ok, [%On{on | steps: steps} | acc]}}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
    |> case do
      {:ok, on} -> {:ok, Enum.reverse(on)}
      {:error, message} -> {:error, message}
    end
  end

  defp expand_spec(nil, _max), do: {:ok, nil}
  defp expand_spec(%Overlay{} = spec, max), do: Overlay.steps(spec, max)

  # The fields of an element

  defp at(element), do: Map.get(element, :at)
  defp on(element), do: Map.get(element, :on) || []
  defp children(element), do: Map.get(element, :elements) || []

  defp put(element, at, on, children) do
    element = %{element | at: at, on: on}

    if Map.has_key?(element, :elements) do
      %{element | elements: children}
    else
      element
    end
  end
end
