# Present a deck

This guide tells you how to give a talk from the HTML document of a deck. You need the
document that `mix expresso` makes and a browser. Each key of each view is in
[The presenter](../reference/presenter.md).

## Show the deck to the audience

1. Open the HTML document in a browser.
2. Press `f` for the full screen.
3. Press `j`, `→` or `Space` for the next step. Press `k` or `←` for the previous step.

A presentation remote sends `Page Down` and `Page Up`, so it works with the deck. A click on
the right two thirds of the window also goes to the next step.

## Use the speaker view on a second screen

The speaker view shows the current step, the next step, the notes of the slide and a timer.

1. Press `s` in the present view. If the browser blocks the second window, let the
   document open windows.
2. Put the speaker window on your screen.
3. Put the first window on the projector, and press `f` in it.

The keys operate in either window, and the two windows show the same step. Press `b` in
the speaker view to give a black screen to the audience, or `w` to give a white screen in
a light room. The next key shows the slide again.

![The speaker view: the current step, the next step, the notes, the position, the timer and the time left](https://raw.githubusercontent.com/rellen/expresso/media/present-speaker.png)

## Keep to the time

1. Write `duration 20` in the deck for a talk of 20 minutes. To give a different length
   with the same file, add `?duration=15` to the address.
2. Look at the time left under the timer in the speaker view. Amber tells you that you are
   more than one minute behind. Red tells you that the time is at its end.
3. Press `r` to set the timer to 0:00 before the talk starts.

## Go to a slide

Use one of these methods:

- Type the number of the slide, then press `Enter`. For example, `1` `2` `Enter` goes to
  slide 12.
- Press `o` for the overview. Select a slide with the arrow keys, then press `Enter`.
- Press `m` for the menu. Move the cursor to a step, then press `Enter`.

In the speaker view, only the speaker window shows the overview and the menu. The step of the
audience changes only at `Enter` or at a click.

## Find a key

1. Press `?` or `/` to open the list of keys.
2. Type a key or a word into the search field, such as `d` or `dark`.
3. Read the rows that agree with the text. The list opens each section that has a row.
4. Press `Tab` to move to a closed section, and press `Enter` or the space bar to open it.
5. Press `Esc` to close the list. A click outside the list also closes it.

The next open of the list shows each row again.

![The list of keys opens, and the word dark leaves the rows of the theme key](https://raw.githubusercontent.com/rellen/expresso/media/present-help.gif)

## Print a handout or make a PDF

1. Press `p` for the handout view. It shows one page for each step that the `handout`
   options select.
2. To print every step, press `a`.
3. Print the page from the browser, or save it as a PDF.

A browser with no window can make the PDF with no key. `?all` at the end of the address
gives each step:

```sh
chromium --headless --print-to-pdf=deck.pdf "file:///path/to/deck.html?all"
```

The name of the command can be `google-chrome` or `chrome`. Without `?all`, the PDF gets
the pages that the `handout` options select. See
[The handout view](../reference/presenter.md#the-handout-view).
