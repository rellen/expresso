defmodule Expresso.Overlay.Render do
  @moduledoc """
  The part of the renderer that writes the CSS contract of the overlays

  `identify/1` gives each element with an `on` entity a value for the
  `data-el` attribute. `attributes/1` makes the `data-on` and `data-el`
  attributes of one element. `style/1` makes the generated style block of a
  deck. `Expresso.Renderer` calls each of them.

  `docs/overlays.md` gives the contract.
  """

  alias Expresso.Deck
  alias Expresso.Element.{On, Pause}
  alias Expresso.Slide

  @doc """
  Give the maximum step number of a slide

  The transformer writes the number into `metadata.max_step`. A slide from the
  imperative API has no such key, and its maximum is 1.
  """
  @spec max_step(Slide.t()) :: pos_integer()
  def max_step(%Slide{metadata: metadata}), do: (metadata || %{})[:max_step] || 1

  @doc """
  Write the identity of each element with an `on` entity

  The value goes into the `el` field of the element. It holds the number of
  the slide and the position of the element in the tree, such as `s2-e1`. The
  position counts each element of the slide in document order, and a parent
  comes before its children. Therefore the value is stable between two renders
  of the same deck. An element without an `on` entity keeps `nil`.
  """
  @spec identify(Deck.t()) :: Deck.t()
  def identify(%Deck{slides: slides} = deck) do
    %Deck{deck | slides: Enum.map(slides, &identify_slide/1)}
  end

  defp identify_slide(%Slide{elements: elements, metadata: metadata} = slide) do
    prefix = "s#{metadata.slide_number}"
    {elements, _position} = identify_elements(elements || [], prefix, 1)
    %Slide{slide | elements: elements}
  end

  defp identify_elements(elements, prefix, position) do
    Enum.map_reduce(elements, position, fn
      %Pause{} = pause, position ->
        {pause, position}

      element, position ->
        el = if on(element) == [], do: nil, else: "#{prefix}-e#{position}"
        {children, position} = identify_elements(children(element), prefix, position + 1)
        {struct(element, el: el, elements: children), position}
    end)
  end

  @doc """
  Make the overlay attributes of one element

  An element with step numbers gets `data-on`, with a space between each
  number. An element with an identity gets `data-el`. The function gives an
  empty list for an element without either, and the render function of the
  element puts the list into its root tag.
  """
  @spec attributes(struct()) :: [{String.t(), String.t()}]
  def attributes(element) do
    on =
      case Map.get(element, :steps) do
        nil -> []
        steps -> [{"data-on", Enum.join(steps, " ")}]
      end

    el =
      case Map.get(element, :el) do
        nil -> []
        el -> [{"data-el", el}]
      end

    on ++ el
  end

  @doc """
  Make the generated style block of a deck

  The block has three parts:

  - One `@property` rule for each state of the deck. It registers the custom
    property as a number with the initial value 0.
  - One rule for each step number to the maximum step number of the deck. It
    shows each element with that number in its `data-on` attribute.
  - One rule for each `on` entity, in document order. It sets the custom
    properties of the entity on the element, at each step of the entity.

  Call `identify/1` first, because the third part reads the `el` field.
  """
  @spec style(Deck.t()) :: String.t()
  def style(%Deck{slides: slides}) do
    ons = Enum.flat_map(slides, &ons/1)

    (properties(ons) ++ reveals(slides) ++ Enum.map(ons, &rule/1))
    |> Enum.join("\n")
  end

  defp properties(ons) do
    ons
    |> Enum.map(fn {_el, %On{state: state}} -> state end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.map(fn state ->
      "@property --#{state} { syntax: \"<number>\"; inherits: false; initial-value: 0; }"
    end)
  end

  defp reveals(slides) do
    max = slides |> Enum.map(&max_step/1) |> Enum.max(fn -> 1 end)

    for step <- 1..max//1 do
      "section[data-step=\"#{step}\"] [data-on~=\"#{step}\"] " <>
        "{ opacity: 1; visibility: visible; transition-delay: 0s; }"
    end
  end

  defp rule({el, %On{steps: steps} = on}) do
    selectors =
      Enum.map_join(steps, ", ", fn step ->
        "section[data-step=\"#{step}\"] [data-el=\"#{el}\"]"
      end)

    "#{selectors} { #{declarations(on)} }"
  end

  defp declarations(%On{state: state, set: set}) do
    state = if state, do: [{state, 1}], else: []

    Enum.map_join(state ++ (set || []), " ", fn {key, value} ->
      "--#{key}: #{css_value(value)};"
    end)
  end

  # A value comes from the deck. The block is inside a `style` element, so the
  # function escapes `<`, and a value cannot close the element.
  defp css_value(value), do: value |> to_string() |> String.replace("<", "\\3c ")

  # The on entities of a slide, each with the identity of its element

  defp ons(%Slide{elements: elements}), do: Enum.flat_map(elements || [], &element_ons/1)

  defp element_ons(%Pause{}), do: []

  defp element_ons(element) do
    el = Map.get(element, :el)
    own = for %On{steps: steps} = on <- on(element), steps not in [nil, []], do: {el, on}
    own ++ Enum.flat_map(children(element), &element_ons/1)
  end

  defp on(element), do: Map.get(element, :on) || []
  defp children(element), do: Map.get(element, :elements) || []
end
