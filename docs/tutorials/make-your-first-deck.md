# Make your first deck

In this tutorial, you write a deck of three slides, render it to one HTML document, and
present it in a browser. Then you add steps and notes, and you check the deck. You need the
tools of [Install](../../README.md#install) and a clone of the repository.

## Write the deck

Make a file `my_deck.exs` in the directory of the repository, with this text:

```elixir
defmodule MyDeck do
  use Expresso

  name "my deck"

  slide do
    heading "Hello"

    text_box do
      text_area do
        text "A text area in a text box. Text accepts <b>HTML</b>."
      end
    end
  end

  slide "points" do
    heading "Two points"

    list do
      item "The first point"
      item "The second point"
    end
  end

  slide "end" do
    heading "Thank you"
  end
end
```

The module declares a deck with the name "my deck". Each `slide` holds a heading and
elements. A slide can have a name, such as `"points"`, and a `goto` link can use it.

## Render the deck

Run this command:

```sh
mix expresso my_deck.exs my_deck.html
```

The command writes one file, `my_deck.html`. The file holds each slide, the styles and the
script of the presenter, so it needs no network.

## Present the deck

1. Open `my_deck.html` in a browser. The first slide shows "Hello".
2. Press `j` two times. The deck goes to the slide "Thank you".
3. Press `k` one time. The deck goes back to the slide "Two points".
4. Press `o`. The overview shows the three slides. Press `o` again to close it.

The address now ends with `#2.1`, which is step 1 of slide 2. A reload shows the same step.

## Show a point at a time

Each slide so far has one step. Add `reveal true` to the list, so that each item gets a
step of its own:

```elixir
    list do
      reveal true
      item "The first point"
      item "The second point"
    end
```

Render the deck again, and reload the page. The slide "Two points" now has two steps. Step 1
shows the first point, and `j` shows the second point. The next `j` goes to the slide
"Thank you". `auto_reveal true` on a slide does the same for each element of the slide.

## Write the deck while you watch it

A render after each change is slow. Start the watch mode in place of it:

```sh
mix expresso my_deck.exs --watch
```

Open `http://127.0.0.1:4100/`. Change the heading "Hello" to "Hello, world", and save the
file. The page reloads, and it shows the new heading at the same step. Stop the watch mode
with Ctrl-C.

## Add notes for the speaker

Add a `notes` option to the first slide:

```elixir
  slide do
    heading "Hello"
    notes "Welcome the audience, and press j."
```

Render the deck, open it, and press `s`. A second window opens with the speaker view. It
shows the current step, the next step, your note and a timer. If the browser blocks the
window, let the document open windows.

## Check the deck

Run the check before a talk:

```sh
mix expresso my_deck.exs --check
```

The command writes a report. For this deck, the report has no problem, and the exit status
is 0. A problem, such as text with a low contrast, gives the exit status 1.

## Next steps

You wrote a deck, presented it and checked it. To go on:

- Read [Present a deck](../how-to/present-a-deck.md) for the speaker view on a second screen,
  the time of a talk and a handout.
- Read [Animate elements in a slide](../how-to/animate-elements.md) for more steps.
- Read [The deck options](../reference/deck-options.md) for a theme, transitions and slide
  numbers.
- Read [Make a deck from data](../how-to/make-a-deck-from-data.md) to make the slides with
  functions in place of the DSL.
