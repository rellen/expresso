defmodule Expresso.Steps do
  @moduledoc """
  Makes the list of each step of a deck for the presenter

  The renderer writes the list into the document as JSON, in the element
  `script#expresso-deck`. The presenter script reads it at load. The script
  holds the index of the current step in the list, and it reads each other
  value from the list. It calculates nothing from the deck.

  The JSON object has three keys:

    * `"steps"` - one entry for each step of each slide, in sequence. An entry
      is `[slide, step, fraction, done, position, previous, next]`. `entries/1`
      tells what each value is.
    * `"slides"` - one object for each slide, in sequence. `slides/1` tells
      what each key is.
    * `"duration_ms"` - the length of the talk in milliseconds, or `null`.
      `duration/1` gives it.

  A slide with the option `hidden true` is not a part of the talk. The list
  holds its steps, because the presenter can go to it. The talk skips it:
  `previous` and `next` of an entry go around each hidden slide, and
  `fraction`, `done` and the numbers of the slides count only the slides of
  the talk. `docs/hidden-slides.md` gives the design.

  `docs/research/elixir-presenter-report.md` gives the reason for the list.
  """

  alias Expresso.{Deck, Slide}
  alias Expresso.Overlay.Render
  alias Expresso.Presenter.Schema.Record

  @typedoc "One step of a deck"
  @type entry :: %{
          slide: pos_integer(),
          step: pos_integer(),
          fraction: float(),
          done: float(),
          position: String.t(),
          previous: non_neg_integer() | nil,
          next: non_neg_integer() | nil
        }

  @typedoc "One slide of a deck"
  @type slide :: %{
          first: non_neg_integer(),
          steps: pos_integer(),
          transition: String.t(),
          number: pos_integer() | nil
        }

  # The number of decimal places of `fraction` and `done`. Four places are
  # sufficient for the width of the progress bar and for the pace.
  @places 4

  @doc """
  Return one entry for each step of each slide, in sequence

  The first slide is slide 1, and the first step is step 1. `slide` is the
  place of the slide in the deck, and a hidden slide has a place too. An
  entry holds:

    * `fraction` - the part of the talk before the step, from 0 at the first
      step to 1 at the last step. The progress bar shows it. A talk with one
      step gets 0.
    * `done` - the part of the steps of the talk before the step. The last
      step also has its part, so the value is less than 1. The speaker view
      compares it with the time of the talk.
    * `position` - the text of the speaker view, such as
      `"Slide 4 of 13, step 2 of 3"`. A slide with one step gets no step part.
      A step with a label gets the label after a colon, such as
      `"Slide 4 of 13, step 2 of 3: The restart"`.
    * `previous` and `next` - the index of the step that the key of the
      previous step and the key of the next step go to, or `nil` at an end of
      the talk.

  The numbers of `position` count only the slides of the talk. A step of a
  hidden slide gets `"Hidden slide after slide 4 of 13"`, and
  `"Hidden slide before slide 1 of 13"` in front of the first slide of the
  talk. Its `fraction` and its `done` are the values of the last step of the
  talk before it, so the progress bar does not move on a hidden slide.

  `previous` and `next` go to the nearest step of the same slide or of a
  slide of the talk. Thus they skip each hidden slide, and on a hidden slide
  they go through its steps and then back into the talk.

  The presenter adds ", black screen" or ", white screen" to the position
  while the screen is black or white.
  """
  @spec entries(Deck.t()) :: [entry()]
  def entries(%Deck{slides: slides} = deck) do
    count = Deck.talk_length(deck)

    # Each step with the number of its slide in the talk. A hidden slide holds
    # the number of the slide of the talk before it, or 0.
    {steps, _shown} =
      slides
      |> Enum.with_index(1)
      |> Enum.flat_map_reduce(0, fn {slide, place}, shown ->
        hidden = Slide.hidden?(slide)
        number = if hidden, do: shown, else: shown + 1
        max = Render.max_step(slide)
        labels = (slide.metadata || %{})[:labels] || %{}

        steps =
          for step <- 1..max//1 do
            %{slide: place, step: step, steps: max, label: labels[step], hidden: hidden}
            |> Map.put(:number, number)
          end

        {steps, number}
      end)

    total = Enum.count(steps, &(not &1.hidden))
    places = steps |> Enum.map(&{&1.slide, &1.hidden}) |> List.to_tuple()

    {entries, _before} =
      steps
      |> Enum.with_index()
      |> Enum.map_reduce(0, fn {step, index}, before ->
        # `before` is the number of steps of the talk in front of this step. A
        # step of a hidden slide takes the place of the step of the talk
        # before it.
        place = if step.hidden, do: max(before - 1, 0), else: before

        entry = %{
          slide: step.slide,
          step: step.step,
          fraction: part(place, total - 1),
          done: part(place, total),
          position: position(step, count) <> step_part(step) <> label(step.label),
          previous: move(places, index, -1),
          next: move(places, index, 1)
        }

        {entry, if(step.hidden, do: before, else: before + 1)}
      end)

    entries
  end

  # The index of the nearest step in a direction that is a step of the same
  # slide or of a slide of the talk, or nil.
  defp move(places, index, by) do
    {slide, _hidden} = elem(places, index)

    (index + by)
    |> Stream.iterate(&(&1 + by))
    |> Enum.find(&(&1 < 0 or &1 >= tuple_size(places) or stays?(elem(places, &1), slide)))
    |> then(&if &1 >= 0 and &1 < tuple_size(places), do: &1)
  end

  defp stays?({slide, _hidden}, slide), do: true
  defp stays?({_other, hidden}, _slide), do: not hidden

  @doc """
  Return one map for each slide, in sequence

  A map holds:

    * `first` - the index of step 1 of the slide in the list of `entries/1`.
    * `steps` - the number of steps of the slide.
    * `transition` - the kind of the transition into the slide, such as
      `"fade"` or `"wipe-down"`. The option of the slide comes first, then the
      option of the deck, then `"fade"`. `kind/1` gives the name.
    * `number` - the number of the slide in the talk, or `nil` for a hidden
      slide. The presenter goes to the slide with this number when the
      presenter types the number.
  """
  @spec slides(Deck.t()) :: [slide()]
  def slides(%Deck{slides: slides} = deck) do
    {list, _next} =
      Enum.map_reduce(slides, {0, 0}, fn slide, {first, shown} ->
        steps = Render.max_step(slide)
        {number, shown} = if Slide.hidden?(slide), do: {nil, shown}, else: {shown + 1, shown + 1}
        entry = %{first: first, steps: steps, transition: transition(deck, slide), number: number}
        {entry, {first + steps, shown}}
      end)

    list
  end

  @doc """
  Return the length of the talk in milliseconds, or nil

  The `duration` option of the deck gives the length in minutes. A value that
  is not a positive integer gives nil. The address parameter `?duration=`
  replaces the length in the browser.
  """
  @spec duration(Deck.t()) :: pos_integer() | nil
  def duration(%Deck{metadata: metadata}) do
    case metadata do
      %{duration: minutes} when is_integer(minutes) and minutes > 0 -> minutes * 60_000
      _other -> nil
    end
  end

  @doc """
  Return the list of the steps as JSON for the `script` element

  `Expresso.Json.for_script/1` writes the text, so it has no `<`, and a value
  cannot close the `script` element.

  The keys of each object are in alphabetical order, so each render of a deck
  gives the same text.
  """
  @spec json(Deck.t()) :: String.t()
  def json(deck) do
    # The keys are strings and not atoms. The order of the atom keys of a small
    # map comes from the order in which the VM made the atoms, and the binary
    # of Burrito makes them in a different order. A map with string keys keeps
    # them in alphabetical order.
    %{
      "steps" => Enum.map(entries(deck), &Record.write(:written_entry, &1)),
      "slides" =>
        Enum.map(slides(deck), fn slide ->
          %{
            "first" => slide.first,
            "number" => slide.number,
            "steps" => slide.steps,
            "transition" => slide.transition
          }
        end),
      "duration_ms" => duration(deck)
    }
    |> Expresso.Json.for_script()
  end

  # The part `index / total`. A total of 0 occurs for a deck with one step.
  defp part(_index, 0), do: 0.0
  defp part(index, total), do: Float.round(index / total, @places)

  defp label(nil), do: ""
  defp label(label), do: ": " <> label

  defp position(%{hidden: false, number: number}, count), do: "Slide #{number} of #{count}"
  defp position(%{hidden: true}, 0), do: "Hidden slide"
  defp position(%{hidden: true, number: 0}, count), do: "Hidden slide before slide 1 of #{count}"

  defp position(%{hidden: true, number: number}, count),
    do: "Hidden slide after slide #{number} of #{count}"

  defp step_part(%{steps: 1}), do: ""
  defp step_part(%{step: step, steps: steps}), do: ", step #{step} of #{steps}"

  defp transition(deck, slide) do
    [(slide.metadata || %{})[:transition], (deck.metadata || %{})[:transition]]
    |> Enum.find(:fade, & &1)
    |> kind()
  end

  @doc """
  Give the kind of a transition, as the presenter and the style sheet write it

  The kind is the name of the atom with a hyphen for each underscore, as for
  an effect. The style sheet then gives the rule for
  `html[data-transition="wipe-down"]`.

      iex> Expresso.Steps.kind(:wipe_down)
      "wipe-down"
  """
  @spec kind(atom()) :: String.t()
  def kind(transition), do: transition |> Atom.to_string() |> String.replace("_", "-")
end
