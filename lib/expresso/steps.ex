defmodule Expresso.Steps do
  @moduledoc """
  Makes the list of each step of a deck for the presenter

  The renderer writes the list into the document as JSON, in the element
  `script#expresso-deck`. The presenter script reads it at load. The script
  holds the index of the current step in the list, and it reads each other
  value from the list. It calculates nothing from the deck.

  The JSON object has three keys:

    * `"steps"` - one entry for each step of each slide, in sequence. An entry
      is `[slide, step, fraction, done, position]`. `entries/1` tells what each
      value is.
    * `"slides"` - one object for each slide, in sequence. `slides/1` tells
      what each key is.
    * `"duration_ms"` - the length of the talk in milliseconds, or `null`.
      `duration/1` gives it.

  `docs/research/elixir-presenter-report.md` gives the reason for the list.
  """

  alias Expresso.Deck
  alias Expresso.Overlay.Render

  @typedoc "One step of a deck"
  @type entry :: %{
          slide: pos_integer(),
          step: pos_integer(),
          fraction: float(),
          done: float(),
          position: String.t()
        }

  @typedoc "One slide of a deck"
  @type slide :: %{first: non_neg_integer(), steps: pos_integer(), transition: String.t()}

  # The number of decimal places of `fraction` and `done`. Four places are
  # sufficient for the width of the progress bar and for the pace.
  @places 4

  @doc """
  Return one entry for each step of each slide, in sequence

  The first slide is slide 1, and the first step is step 1. An entry holds:

    * `fraction` - the part of the deck before the step, from 0 at the first
      step to 1 at the last step. The progress bar shows it. A deck with one
      step gets 0.
    * `done` - the part of the steps before the step. The last step also has
      its part, so the value is less than 1. The speaker view compares it with
      the time of the talk.
    * `position` - the text of the speaker view, such as
      `"Slide 4 of 13, step 2 of 3"`. A slide with one step gets no step part.

  The presenter adds ", black screen" to the position while the screen is black.
  """
  @spec entries(Deck.t()) :: [entry()]
  def entries(%Deck{slides: slides}) do
    count = length(slides)

    positions =
      for {slide, number} <- Enum.with_index(slides, 1),
          steps = Render.max_step(slide),
          step <- 1..steps//1,
          do: {number, step, steps}

    total = length(positions)

    positions
    |> Enum.with_index()
    |> Enum.map(fn {{number, step, steps}, index} ->
      %{
        slide: number,
        step: step,
        fraction: part(index, total - 1),
        done: part(index, total),
        position: position(number, count, step, steps)
      }
    end)
  end

  @doc """
  Return one map for each slide, in sequence

  A map holds:

    * `first` - the index of step 1 of the slide in the list of `entries/1`.
    * `steps` - the number of steps of the slide.
    * `transition` - the kind of the transition into the slide, such as
      `"fade"` or `"wipe-down"`. The option of the slide comes first, then the
      option of the deck, then `"fade"`. `kind/1` gives the name.
  """
  @spec slides(Deck.t()) :: [slide()]
  def slides(%Deck{slides: slides} = deck) do
    {list, _next} =
      Enum.map_reduce(slides, 0, fn slide, first ->
        steps = Render.max_step(slide)
        {%{first: first, steps: steps, transition: transition(deck, slide)}, first + steps}
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

  The text has no `<`, so a value cannot close the `script` element. Each `<`
  becomes `\\u003c`, which JSON reads as the same character.

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
      "steps" => Enum.map(entries(deck), &[&1.slide, &1.step, &1.fraction, &1.done, &1.position]),
      "slides" =>
        Enum.map(slides(deck), fn slide ->
          %{"first" => slide.first, "steps" => slide.steps, "transition" => slide.transition}
        end),
      "duration_ms" => duration(deck)
    }
    |> JSON.encode!()
    |> String.replace("<", "\\u003c")
  end

  # The part `index / total`. A total of 0 occurs for a deck with one step.
  defp part(_index, 0), do: 0.0
  defp part(index, total), do: Float.round(index / total, @places)

  defp position(number, count, _step, 1), do: "Slide #{number} of #{count}"

  defp position(number, count, step, steps),
    do: "Slide #{number} of #{count}, step #{step} of #{steps}"

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
