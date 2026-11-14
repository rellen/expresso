# Write notes for the speaker

This guide shows how to write the notes that only you see during a talk, with bold text
and lists, and how to give a step its own note.

## Write a note for a slide

Write the `notes` option in the slide. The text is Markdown, and three quotation marks
let the text go on more than one line.

```elixir
defmodule Examples.SpeakerNotes do
  use Expresso

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
    note "Show the log with `mix run`. Then go to the next slide.", at: 3
  end
end

Examples.SpeakerNotes
```

![The speaker view at three steps: the note of the slide stays, and the note under it changes with the step](https://raw.githubusercontent.com/rellen/expresso/media/speaker-notes.gif)

- `**slow**` gives bold text, and a line that starts with `-` is an item of a list.
- A line break in a paragraph stays a line break.

Press `s` in the present view to open the speaker view. See
[Present a deck](present-a-deck.md#use-the-speaker-view-on-a-second-screen).

## Give a step its own note

Write a `note` in the slide, with the step in the `at` option. The example above has a
note for step 2 and a note for step 3.

1. Count the steps of the slide. The list with `reveal true` shows its first item at
   step 1, its second item at step 2 and its third item at step 3.
2. Write `note "Ask the room.", at: 2` at the level of the slide.
3. Open the speaker view, and press `j`. The note of the step shows under the note of the
   slide.

`at: [from: 2]` gives the note to step 2 and to each step after it, and `at: 2..3` gives
it to two steps. A `note` adds no step to the slide.

## Print the notes

Press `p` for the handout view, and print the page. Each page has the notes of its step
under the slide.

- `handout :last` in the deck prints one page for each slide. That page then has the
  notes of each step of the slide, and each note of an earlier step has a label, such as
  `Step 2`.
- `print_notes false` in the deck leaves the notes out of the handout view and of the
  print.

See [The note element](../reference/note-element.md) for each form of the Markdown, and
for the notes in the binary of Expresso.
