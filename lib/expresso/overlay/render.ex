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

  The function also writes the effect of each element into its `effect`
  field. The effect is the nearest value of these: the `effect` field of the
  element, the field of the nearest parent with a value, the `:effect` key of
  the metadata of the slide, and the key of the metadata of the deck. The
  default is `:fade`. A list with `reveal true` and an effect therefore gives
  the effect to each item.

  The `speed` and `easing` fields follow the same rule. They have no default,
  and `nil` gives the time and the easing of the theme.
  """
  @spec identify(Deck.t()) :: Deck.t()
  def identify(%Deck{slides: slides, metadata: metadata} = deck) do
    defaults = %{effect: :fade, speed: nil, easing: nil}
    timing = nearest(defaults, metadata || %{})
    %Deck{deck | slides: Enum.map(slides, &identify_slide(&1, timing))}
  end

  # The keys that an element takes from the nearest parent, the slide or the
  # deck.
  @inherited [:effect, :speed, :easing]

  defp nearest(values, source) do
    Map.new(@inherited, fn key -> {key, Map.get(source, key) || values[key]} end)
  end

  defp identify_slide(%Slide{elements: elements, metadata: metadata} = slide, values) do
    prefix = "s#{metadata.slide_number}"

    {elements, _position} =
      identify_elements(elements || [], prefix, 1, nearest(values, metadata))

    %Slide{slide | elements: elements}
  end

  defp identify_elements(elements, prefix, position, values) do
    Enum.map_reduce(elements, position, fn
      %Pause{} = pause, position ->
        {pause, position}

      element, position ->
        el = if on(element) == [], do: nil, else: "#{prefix}-e#{position}"
        values = nearest(values, element)

        {children, position} =
          identify_elements(children(element), prefix, position + 1, values)

        {struct(element, [el: el, elements: children] ++ Map.to_list(values)), position}
    end)
  end

  @doc """
  Make the overlay attributes of one element

  An element with step numbers gets `data-on`, with a space between each
  number, and `data-effect` for an effect that is not `:fade`, such as
  `data-effect="fly-up"`. An element with an identity gets `data-el`. An
  element with either also gets `data-speed` and `data-easing` for a value
  that is not `nil`, such as `data-speed="slow"`, `data-speed="450"` and
  `data-easing="ease-out"`. The function gives an empty list for an element
  without steps and without an identity, and the render function of the
  element puts the list into its root tag.
  """
  @spec attributes(struct()) :: [{String.t(), String.t()}]
  def attributes(element) do
    on =
      case Map.get(element, :steps) do
        nil -> []
        steps -> [{"data-on", Enum.join(steps, " ")} | effect(Map.get(element, :effect))]
      end

    el =
      case Map.get(element, :el) do
        nil -> []
        el -> [{"data-el", el}]
      end

    case on ++ el do
      [] -> []
      attributes -> attributes ++ timing(element)
    end
  end

  # The speed and the easing of an element that animates. An element without
  # a value uses the time and the easing of its parent, as CSS inherits them.
  defp timing(element) do
    for key <- [:speed, :easing], value = Map.get(element, key), value != nil do
      {"data-#{key}", value(value)}
    end
  end

  defp value(value) when is_integer(value), do: Integer.to_string(value)
  defp value(value), do: value |> Atom.to_string() |> String.replace("_", "-")

  # The fade is the rule of the theme for each element with steps, so it needs
  # no attribute. The value uses hyphens, as the other values of the theme do.
  defp effect(effect) when effect in [nil, :fade], do: []

  defp effect(effect), do: [{"data-effect", value(effect)}]

  @doc """
  Make the generated style block of a deck

  The block has three parts:

  - One `@property` rule for each state of the deck. It registers the custom
    property as a number with the initial value 0.
  - One rule for each step number to the maximum step number of the deck. It
    shows each element with that number in its `data-on` attribute, and it
    sets `--shown: 1`. The theme reads that property for an effect.
  - One rule for each `on` entity, in document order. It sets the custom
    properties of the entity on the element, at each step of the entity.
  - One rule for each speed in milliseconds of the deck, such as
    `[data-speed="450"] { --speed: 450ms; }`. The theme gives the presets.

  Call `identify/1` first, because the third and the fourth parts read the
  fields that it writes.
  """
  @spec style(Deck.t()) :: String.t()
  def style(%Deck{slides: slides}) do
    ons = Enum.flat_map(slides, &ons/1)

    (properties(ons) ++ reveals(slides) ++ Enum.map(ons, &rule/1) ++ speeds(slides))
    |> Enum.join("\n")
  end

  # A speed in milliseconds has no preset in the theme, so the block gives it
  # its time. Only an element that animates writes `data-speed`.
  defp speeds(slides) do
    slides
    |> Enum.flat_map(&elements(&1.elements || []))
    |> Enum.filter(&(Map.get(&1, :steps) != nil or Map.get(&1, :el) != nil))
    |> Enum.map(&Map.get(&1, :speed))
    |> Enum.filter(&is_integer/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&"[data-speed=\"#{&1}\"] { --speed: #{&1}ms; }")
  end

  defp elements(elements) do
    Enum.flat_map(elements, fn
      %Pause{} -> []
      element -> [element | elements(children(element))]
    end)
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
        "{ opacity: 1; visibility: visible; transition-delay: 0s; --shown: 1; }"
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
