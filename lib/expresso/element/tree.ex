defmodule Expresso.Element.Tree do
  @moduledoc """
  The walks over a tree of elements

  A container, such as a text box, a column or a list, holds its children
  under the key `:elements`. Each function of this module reads the children
  of an element with `children/1`, so each walk reads them in the same way.
  An element without the key, such as a `pause`, has no children, and `nil`
  is an empty list.

  Each function visits the elements in document order: an element comes
  before its children, and its children come before the next element. A
  function that changes the elements calls the function of the caller on an
  element first, and then it walks the children of the result.

  The overlay expansion, the overlay check, `Expresso.Overlay.Render.identify/1`
  and `Expresso.Placement` keep their own walks, because they carry the
  context of the parent or they have their own rules. The first three read
  the children with `children/1` too. `Expresso.Placement` also reads the
  key `:timeline` of a chart.
  """

  alias Shoddy.Result

  @typedoc "An element struct, or a different map with the key `:elements`"
  @type element :: map()

  @doc """
  Return the children of an element

  The function returns `[]` for an element without the key `:elements`, and
  for the value `nil`.

      iex> Expresso.Element.Tree.children(%{elements: [%{text: "a"}]})
      [%{text: "a"}]
      iex> Expresso.Element.Tree.children(%{elements: nil})
      []
      iex> Expresso.Element.Tree.children(%{text: "a"})
      []
  """
  @spec children(element()) :: [element()]
  def children(element) do
    case Map.get(element, :elements) do
      children when is_list(children) -> children
      nil -> []
    end
  end

  @doc """
  Return each element of a list and each element under it, in document order

      iex> tree = [%{name: "a", elements: [%{name: "b"}]}, %{name: "c"}]
      iex> tree |> Expresso.Element.Tree.descendants() |> Enum.map(& &1.name)
      ["a", "b", "c"]
  """
  @spec descendants([element()] | nil) :: [element()]
  def descendants(elements) do
    Enum.flat_map(elements || [], &[&1 | descendants(children(&1))])
  end

  @doc """
  Change each element of a list and each element under it

  The function calls `fun` on an element, and then it changes the children
  of the result. An element without the key `:elements` stays without it.
  """
  @spec map([element()] | nil, (element() -> element())) :: [element()]
  def map(elements, fun) do
    Enum.map(elements || [], fn element ->
      element |> fun.() |> put_children(&map(&1, fun))
    end)
  end

  @doc """
  Change each element of a list and each element under it, with a value that
  goes from one element to the next

  `fun` takes an element and the value, and it returns the changed element
  and the next value, as for `Enum.map_reduce/3`.
  """
  @spec map_reduce([element()] | nil, acc, (element(), acc -> {element(), acc})) ::
          {[element()], acc}
        when acc: term()
  def map_reduce(elements, acc, fun) do
    Enum.map_reduce(elements || [], acc, fn element, acc ->
      {element, acc} = fun.(element, acc)

      if is_map_key(element, :elements) do
        {children, acc} = map_reduce(children(element), acc, fun)
        {%{element | elements: children}, acc}
      else
        {element, acc}
      end
    end)
  end

  @doc """
  Change each element of each slide of a deck, as `map/2` does

  The function takes a deck or a different map with the key `:slides`.
  """
  @spec map_deck(deck, (element() -> element())) :: deck when deck: map()
  def map_deck(%{slides: slides} = deck, fun) do
    %{deck | slides: Enum.map(slides, &%{&1 | elements: map(&1.elements, fun)})}
  end

  @doc """
  Change each element of each slide of a deck, with a value that goes from
  one element to the next, as `map_reduce/3` does

  The value goes from the last element of a slide to the first element of
  the next slide.
  """
  @spec map_reduce_deck(deck, acc, (element(), acc -> {element(), acc})) :: {deck, acc}
        when deck: map(), acc: term()
  def map_reduce_deck(%{slides: slides} = deck, acc, fun) do
    {slides, acc} =
      Enum.map_reduce(slides, acc, fn slide, acc ->
        {elements, acc} = map_reduce(slide.elements, acc, fun)
        {%{slide | elements: elements}, acc}
      end)

    {%{deck | slides: slides}, acc}
  end

  @doc """
  Change each element of a list and each element under it, and stop at the
  first error

  `fun` returns `{:ok, element}` or `{:error, reason}`. The function returns
  `{:ok, elements}`, or the first error in document order.
  """
  @spec map_ok([element()] | nil, (element() -> {:ok, element()} | {:error, reason})) ::
          {:ok, [element()]} | {:error, reason}
        when reason: term()
  def map_ok(elements, fun) do
    (elements || [])
    |> Stream.map(&map_one_ok(&1, fun))
    |> Result.collect()
  end

  defp map_one_ok(element, fun) do
    with {:ok, element} <- fun.(element) do
      if is_map_key(element, :elements),
        do: element |> children() |> map_ok(fun) |> Result.map_ok(&%{element | elements: &1}),
        else: {:ok, element}
    end
  end

  defp put_children(element, fun) when is_map_key(element, :elements),
    do: %{element | elements: fun.(children(element))}

  defp put_children(element, _fun), do: element
end
