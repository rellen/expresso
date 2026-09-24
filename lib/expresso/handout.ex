defmodule Expresso.Handout do
  @moduledoc """
  The steps of a slide that the handout view shows and that a printer prints

  The `handout` option of a slide takes `:all`, `:last`, or the steps of the
  slide in the forms of an overlay specification, such as `3`, `2..4`,
  `[2, 5]` or `[from: 3]`. A list can also hold `:last`, such as `[2, :last]`,
  so an author can name the last step without its number. A `:next` has no
  meaning here, because no counter runs for this option.

  The `handout` option of the deck takes `:all` or `:last`, and it gives the
  value for each slide without the option. The default is `:all`.

  The renderer writes a page for each step of each slide, because the speaker
  view shows the pages of the current step and of the next step. It marks each
  page that this module does not select, and the style sheet then hides that
  page in the handout view and on paper.
  """

  alias Expresso.Overlay

  @typedoc "A selection of steps: an overlay specification, the last step, or both"
  @type t :: %__MODULE__{overlay: Overlay.t() | nil, last: boolean()}

  defstruct overlay: nil, last: false

  @forms "the handout option must be :all, :last, or the steps of the slide, " <>
           "such as 3, 2..4, [2, 5], [from: 3] or [2, :last]"

  @doc """
  Make a selection from the value of a `handout` option
  """
  @spec new(term()) :: {:ok, t()} | {:error, String.t()}
  def new(%__MODULE__{} = handout), do: {:ok, handout}
  def new(:all), do: {:ok, all()}
  def new(:last), do: {:ok, %__MODULE__{last: true}}
  def new([]), do: {:error, @forms}

  def new(items) when is_list(items) do
    case Enum.split_with(items, &(&1 == :last)) do
      {_last, []} -> {:ok, %__MODULE__{last: true}}
      {last, rest} -> with_overlay(rest, last != [])
    end
  end

  def new(term), do: with_overlay(term, false)

  defp with_overlay(term, last) do
    case Overlay.new(term) do
      {:ok, overlay} ->
        if Overlay.relative?(overlay) do
          {:error, "the handout option cannot hold :next, because no counter runs for it"}
        else
          {:ok, %__MODULE__{overlay: overlay, last: last}}
        end

      {:error, _message} ->
        {:error, @forms}
    end
  end

  defp all do
    {:ok, overlay} = Overlay.new(from: 1)
    %__MODULE__{overlay: overlay}
  end

  @doc """
  Give the steps of a selection, with `max` as the maximum step of the slide

  The function gives the steps in order with no repeat. It gives an error for
  a step that the slide does not have.
  """
  @spec pages(t(), pos_integer()) :: {:ok, [pos_integer()]} | {:error, String.t()}
  def pages(%__MODULE__{overlay: overlay, last: last}, max) when is_integer(max) and max >= 1 do
    with {:ok, steps} <- steps(overlay, max) do
      steps = if last, do: [max | steps], else: steps
      {:ok, steps |> Enum.uniq() |> Enum.sort()}
    end
  end

  defp steps(nil, _max), do: {:ok, []}

  defp steps(overlay, max) do
    case Overlay.steps(overlay, max) do
      {:ok, steps} -> {:ok, steps}
      {:error, message} -> {:error, "the handout option has a step of no page: " <> message}
    end
  end

  @doc """
  Give the steps of a slide that the handout view shows

  The slide gives its selection in the `handout` key of its metadata, and the
  deck gives the selection for each slide without that key. The function
  raises an `ArgumentError` for a selection that is not valid. The DSL finds
  such a selection at compile time, so only a deck from the imperative API can
  raise here.
  """
  @spec printed(Expresso.Deck.t(), Expresso.Slide.t()) :: [pos_integer()]
  def printed(deck, slide) do
    term = metadata(slide)[:handout] || metadata(deck)[:handout] || :all
    max = Overlay.Render.max_step(slide)

    with {:ok, handout} <- new(term),
         {:ok, steps} <- pages(handout, max) do
      steps
    else
      {:error, message} ->
        raise ArgumentError, "slide #{metadata(slide)[:slide_number]}: #{message}"
    end
  end

  defp metadata(%{metadata: metadata}) when is_map(metadata), do: metadata
  defp metadata(_value), do: %{}
end
