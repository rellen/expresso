defmodule Expresso.Notes do
  @moduledoc """
  The notes of the speaker of a slide, as HTML

  A slide has two sources of notes:

  - the `notes` option of the slide, which is a note for each step,
  - each `note` entity of the slide, which is a note for the steps of its
    `at` option. `Expresso.Element.Note` gives the entity.

  The text of a note is Markdown. `html/1` makes its HTML with MDEx:

  | Markdown | HTML |
  | --- | --- |
  | `**bold**`, `*italic*`, `~~old~~` | `strong`, `em`, `del` |
  | `` `code` `` and a block between two lines of three backticks | `code`, and `pre` with `code` |
  | `- item` and `1. item` | `ul` and `ol` |
  | `[text](https://example.com)` and an address | `a` |
  | a line break | `br` |

  HTML in a note shows as text, so a note can hold `<Enter>`.

  MDEx is a NIF, and it is a dependency with `runtime: false`. A release, such
  as the binary of Burrito, does not hold it, because the precompiled library
  of MDEx does not load in the ERTS of that binary. `markdown?/0` tells if
  MDEx is available. Without MDEx, `html/1` returns the text of the note as
  it is, in one paragraph with the class `note-plain`.

  The application environment `config :expresso, notes_markdown: false` also
  gives the notes with no Markdown. A test of the binary uses it to make the
  document that the binary writes. `docs/speaker-notes.md` gives the design.
  """

  alias Expresso.Element.Note

  @options [
    extension: [autolink: true, strikethrough: true],
    render: [hardbreaks: true, escape: true]
  ]

  @typedoc """
  The notes of a slide: the HTML of each note, with the steps of the note

  The steps are `nil` for a note for each step.
  """
  @type notes :: [{[pos_integer()] | nil, String.t()}]

  @typedoc """
  One note of a page of the handout view

  `label` is `nil` for a note of the step of the page and for a note for each
  step. For a note of an earlier step that has no page of its own, it names
  the steps, such as `"Step 2"`.
  """
  @type entry :: %{html: String.t(), label: String.t() | nil}

  @doc """
  Tell if MDEx is available, so a note shows its Markdown

      iex> Expresso.Notes.markdown?()
      true
  """
  @spec markdown?() :: boolean()
  def markdown?, do: match?({:ok, _html}, convert("a"))

  @doc """
  Make the HTML of the text of a note

      iex> Expresso.Notes.html("Ask the **room**.")
      "<p>Ask the <strong>room</strong>.</p>"

      iex> Expresso.Notes.html("Press <Enter>.\\nThen wait.")
      "<p>Press &lt;Enter&gt;.<br />\\nThen wait.</p>"
  """
  @spec html(String.t()) :: String.t()
  def html(text) do
    case convert(text) do
      {:ok, html} -> String.trim_trailing(html)
      :error -> plain(text)
    end
  end

  defp convert(text) do
    with true <- Application.get_env(:expresso, :notes_markdown, true),
         true <- Code.ensure_loaded?(MDEx),
         {:ok, html} <- MDEx.to_html(text, @options) do
      {:ok, html}
    else
      _no_markdown -> :error
    end
  end

  @doc """
  Make the HTML of a note with no Markdown: the text in one paragraph

  The style sheet keeps each line break of the paragraph.

      iex> Expresso.Notes.plain("Ask the **room** & <wait>.")
      ~s(<p class="note-plain">Ask the **room** &amp; &lt;wait&gt;.</p>)
  """
  @spec plain(String.t()) :: String.t()
  def plain(text) do
    escaped = text |> String.trim() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    ~s(<p class="note-plain">#{escaped}</p>)
  end

  @doc """
  Return the notes of a slide: the `notes` option, then each `note` entity

  The function makes the HTML of each note one time, and `of_page/3` reads
  the result for each page of the slide.
  """
  @spec of_slide(Expresso.Slide.t()) :: notes()
  def of_slide(slide) do
    option =
      case (slide.metadata || %{})[:notes] do
        text when is_binary(text) and text != "" -> [{nil, html(text)}]
        _no_notes -> []
      end

    option ++ for %Note{text: text, steps: steps} <- Note.of_slide(slide), do: {steps, html(text)}
  end

  @doc """
  Return the notes of the page of one step of a slide

  `printed` holds the steps of the slide that the handout view shows, from
  `Expresso.Handout.printed/2`. The page of a step holds these notes, in the
  order of the deck:

  - each note for each step,
  - each note of its step,
  - on a page that the handout view shows, each note of an earlier step that
    has no page there. Such a note has a label with its steps.

  Paper then shows each note of a slide, also with `handout :last`.

      iex> notes = [{nil, "<p>Slide</p>"}, {[2], "<p>Two</p>"}, {[3], "<p>Three</p>"}]
      iex> Expresso.Notes.of_page(notes, 3, [1, 2, 3])
      [%{html: "<p>Slide</p>", label: nil}, %{html: "<p>Three</p>", label: nil}]
      iex> Expresso.Notes.of_page(notes, 3, [3])
      [
        %{html: "<p>Slide</p>", label: nil},
        %{html: "<p>Two</p>", label: "Step 2"},
        %{html: "<p>Three</p>", label: nil}
      ]
  """
  @spec of_page(notes(), pos_integer(), [pos_integer()]) :: [entry()]
  def of_page(notes, step, printed) do
    earlier = earlier(step, printed)

    Enum.flat_map(notes, fn
      {nil, html} -> [%{html: html, label: nil}]
      {steps, html} -> entry(html, steps, step, earlier)
    end)
  end

  # The steps before the step of a page that have no page in the handout
  # view. A page that the handout view does not show has no such step.
  defp earlier(step, printed) do
    if step in printed do
      before = printed |> Enum.filter(&(&1 < step)) |> Enum.max(fn -> 0 end)
      Enum.to_list((before + 1)..(step - 1)//1)
    else
      []
    end
  end

  defp entry(html, steps, step, earlier) do
    cond do
      step in steps ->
        [%{html: html, label: nil}]

      (covered = Enum.filter(steps, &(&1 in earlier))) != [] ->
        [%{html: html, label: label(covered)}]

      true ->
        []
    end
  end

  defp label([step]), do: "Step #{step}"
  defp label(steps), do: "Steps " <> Enum.join(steps, ", ")
end
