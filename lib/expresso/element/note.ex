defmodule Expresso.Element.Note do
  @moduledoc """
  A note of the speaker for some steps of a slide

  The `note` entity takes its text as its first argument, and the `at` option
  gives the steps of the note:

      note "Ask the room for a number.", at: 2
      note "The answer stays on the screen.", at: [from: 3]

  The text is Markdown, as the text of the `notes` option of a slide.
  `Expresso.Notes` makes its HTML. A note with no `at` option is a note for
  each step of the slide.

  A note shows nothing on the slide. The speaker view shows the notes of the
  current step, and a page of the handout view shows the notes of its step,
  under the note of the slide. `docs/speaker-notes.md` gives the design.

  The `at` option takes the forms of an overlay specification with step
  numbers, such as `3`, `2..4`, `[2, 5]` and `[from: 3]`. It takes no `:next`,
  because a note takes no step from the counter of the slide. A note does not
  add a step to its slide, so a step that the slide does not have is an error.
  """

  alias Expresso.Overlay

  @typedoc """
  The struct of a note

  `at` holds the specification of the steps, and `steps` holds the step
  numbers after the expansion of the overlays. A note for each step has `nil`
  in both.
  """
  @type t :: %__MODULE__{
          text: String.t() | nil,
          at: Overlay.t() | nil,
          steps: [pos_integer()] | nil
        }

  defstruct [:text, :at, :steps, __spark_metadata__: nil]

  @doc """
  Make the specification of the `at` option of a note

  This function is the custom type of the option.

      iex> {:ok, spec} = Expresso.Element.Note.at(from: 3)
      iex> spec.pairs
      [{3, :max}]

      iex> Expresso.Element.Note.at(:next)
      {:error, "the at option of a note cannot hold :next, because a note takes no step from the counter of the slide. Give a step number, such as 2"}
  """
  @spec at(term()) :: {:ok, Overlay.t()} | {:error, String.t()}
  def at(term) do
    with {:ok, spec} <- Overlay.new(term) do
      if Overlay.relative?(spec) do
        {:error,
         "the at option of a note cannot hold :next, because a note takes no step from " <>
           "the counter of the slide. Give a step number, such as 2"}
      else
        {:ok, spec}
      end
    end
  end

  @doc """
  Return the notes of a slide, in the order of the deck

  A note is at the level of the slide. `Expresso.PlacementTransformer`
  refuses a note inside an element.

      iex> alias Expresso.Builder
      iex> slide = Builder.slide("s", elements: [Builder.note("one", at: 1), Builder.note("two")])
      iex> slide |> Expresso.Element.Note.of_slide() |> Enum.map(& &1.text)
      ["one", "two"]
  """
  @spec of_slide(map()) :: [t()]
  def of_slide(slide), do: for(%__MODULE__{} = note <- slide.elements || [], do: note)
end
