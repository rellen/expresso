# The note element

The `note` element gives a note of the speaker for some steps of a slide. The `notes`
option of a slide gives a note for each step. The speaker view and the handout view show
the notes, and the audience does not see them.

```elixir
slide "restart" do
  heading "A worker stops"

  notes """
  Go **slow** on this slide.

  - Name the three workers
  - Do not show the code
  """

  list do
    reveal true
    item "The supervisor starts three workers"
    item "One worker stops with an error"
    item "The supervisor starts it again"
  end

  note "Ask: *who saw this error before?*", at: 2
  note "Show the log with `mix run`.", at: 3
end
```

`Expresso.Builder` takes the same options, such as `note("Ask the room.", at: 2)`, in the
`elements` list of the slide. For the design, see [The notes of the speaker](../speaker-notes.md).

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument, or `text` | A string, required | The text of the note, in Markdown. |
| `at` | Step numbers, such as `2`, `2..4`, `[2, 5]` or `[from: 3]` | The steps of the note. Without the option, the note is for each step. |

These rules apply:

- Write a note at the level of the slide. The compiler refuses a note inside an element.
  See [The places of the elements](placement.md).
- A note shows nothing on the slide.
- The `at` option takes no `:next`, because a note takes no step from the counter of the
  slide. The `auto_reveal` option of a slide gives a note no step.
- A note does not add a step to its slide. A step that the slide does not have is an
  error.

## The notes option of a slide

`notes "Welcome the audience."` in a slide gives a note for each step of the slide. Its
text is Markdown, as the text of a `note`. A `note` with no `at` option has the same
effect, and you can write it near the element that it tells about.

## The Markdown of a note

| You write | The note shows |
| --- | --- |
| `**bold**`, `*italic*` and `~~old~~` | Bold text, italic text and text with a line through it. |
| `` `mix test` `` | Code in the line. |
| Three backticks on a line, the code, and three backticks on a line | A block of code. |
| `- item` at the start of a line | A list with bullets. |
| `1. item` at the start of a line | A list with numbers. |
| `[the book](https://example.com)` | A link. An address, such as `https://example.com`, is also a link. |
| `> text` at the start of a line | A quotation. |
| An empty line | A new paragraph. |

A line break in a paragraph stays a line break. HTML in a note shows as text, so a note
can hold `<Enter>`.

## Where the notes show

| View | Notes |
| --- | --- |
| The present view | None. |
| The speaker view | The notes for each step, then the notes of the current step, in the order of the deck. |
| A page of the handout view, and paper | The notes for each step, then the notes of the step of the page. |
| A page with [the handout option](presenter.md#the-handout-view) | Also the notes of each earlier step that has no page, under the label of the step, such as `Step 2`. |

The deck option `print_notes false` leaves the notes out of the handout view and of the
print. The speaker view shows them. See [The deck options](deck-options.md).

## The Markdown library

[MDEx](https://hexdocs.pm/mdex) makes the HTML of the notes. It is a dependency of
Expresso, and `mix expresso` in your project uses it with no step from you.

The binary of Expresso does not hold MDEx, because the library of MDEx does not load in
the binary. The binary shows the text of each note as you wrote it, with its line breaks.
`--check` then gives this note:

```
The notes of the speaker show as plain text, because MDEx is not available.
```

A release of your own that holds Expresso is the same. Add `{:mdex, "~> 0.14"}` to the
dependencies of that release to get the Markdown.

## Accessibility

The notes of a page are an `aside` element with the name `Notes:` and the name of the
page. The speaker view holds the notes of the current step as text and lists, so a screen
reader reads them as it reads each other text. See [Accessibility](accessibility.md).
