# The presenter

This page describes each view of the presenter, its keys, and the parts of the address.
The HTML document holds the presenter, so a browser needs no other file to present the
deck. For the steps of a talk, see [Present a deck](../how-to/present-a-deck.md).

## The views

| View | Opens with | Shows |
| --- | --- | --- |
| Present view | The address of the document | The current step, for the audience |
| Overview | `o` | Each slide at its last step, in a grid |
| Menu | `m` | Each slide and its steps, in a list |
| Speaker view | `s` | The current step, the next step, the notes and a timer, in a second window |
| Handout view | `p` | One page for each step, for a printer |

`?` or `/` opens the search of the keys in each view. The keys of the current view come
first, in groups. The keys of each other view are in a closed section below them.

## The present view

The present view knows these keys:

<!-- keys present -->

| Key | Action |
| --- | --- |
| `j`, `→`, `↓`, `Page Down`, `Space` | Next step, or the first step of the next slide |
| `k`, `←`, `↑`, `Page Up` | Previous step, or the last step of the previous slide |
| `Home` | First slide |
| `End` | Step 1 of the last slide |
| 0 to 9 | Type a slide number |
| `Enter` | Step 1 of the slide that you typed |
| `o` | Overview of the slides. Only this window shows it. |
| `m` | Menu of the slides and their steps. Only this window shows it. |
| `b` | Black screen. The next key shows the slide again. |
| `d` | Code and charts in full color until the next step, in the two windows |
| `t` | Light or dark variant of the theme, in the two windows |
| `g` | Progress bar on or off |
| `f` | Full screen on or off |
| `s` | Speaker view, in a second window |
| `p` | Handout view |
| `?`, `/` | The search of the keys and commands. Esc closes it. |
| Click or tap the right two thirds, or swipe left | Next step |
| Click or tap the left third, or swipe right | Previous step |
| Click or tap a link | The slide and the step of the link |

<!-- /keys -->

To go to a slide, type its number, then press `Enter`. For example, `1` `2` `Enter` goes
to slide 12. The number shows in the top right corner until `Enter`.

A presentation remote sends `Page Down` and `Page Up`, so it works with the deck.

![Three steps forward, one step back, a black screen, and the last slide](https://raw.githubusercontent.com/rellen/expresso/media/present-keys.gif)

### The mouse and the touch screen

A click or a tap on the right two thirds of the window goes to the next step. A click or a
tap on the left third goes to the previous step. On a touch screen, swipe left for the next
step, and swipe right for the previous step. A click on a link of the `goto` option goes to
its slide and step. A click on another link goes to the link.

## The overview

The overview shows each slide at its last step, in a grid that fits the window. In the
speaker view, only the speaker window shows the overview. The overview knows these keys:

<!-- keys overview -->

| Key | Action |
| --- | --- |
| `?`, `/` | The search of the keys and commands. Esc closes it. |
| `j`, `→`, `Page Down`, `Space` | Select the next slide |
| `k`, `←`, `Page Up` | Select the previous slide |
| `↓` | Select the slide below |
| `↑` | Select the slide above |
| `Home` | Select the first slide |
| `End` | Select the last slide |
| `Enter` | Step 1 of the selected slide |
| Click or tap a slide | Step 1 of that slide |
| `o`, `Esc` | Close the overview. The step does not change. |

<!-- /keys -->

![The overview opens, the selection moves two slides, and Enter goes to that slide](https://raw.githubusercontent.com/rellen/expresso/media/present-overview.gif)

## The menu

The menu lists each slide with a small picture of its last step, and the steps of each
slide under it. A step shows its number and its label. See [Step labels](step-labels.md).
`m` opens the menu with the cursor at the current step, and the step of the audience
changes only at `Enter` or at a click. In the speaker view, only the speaker window shows
the menu. The menu knows these keys:

<!-- keys menu -->

| Key | Action |
| --- | --- |
| `?`, `/` | The search of the keys and commands. Esc closes it. |
| `j`, `↓` | Move the cursor to the next step |
| `k`, `↑` | Move the cursor to the previous step |
| `Enter` | The step of the cursor |
| Click or tap a step or a slide | That step |
| `m`, `Esc` | Close the menu. The step does not change. |

<!-- /keys -->

![The menu opens, the cursor moves two steps, and Enter goes to that step](https://raw.githubusercontent.com/rellen/expresso/media/present-menu.gif)

## The speaker view

The speaker view shows the current step, the next step, the notes of the slide, the
position and a timer. The position ends with the label of the step, when the slide gives
one. The keys operate in either window, and the two windows show the same step. `b` in the
speaker view gives a black screen to the audience. The speaker view knows these keys:

<!-- keys speaker -->

| Key | Action |
| --- | --- |
| `j`, `→`, `↓`, `Page Down`, `Space` | Next step, or the first step of the next slide |
| `k`, `←`, `↑`, `Page Up` | Previous step, or the last step of the previous slide |
| `Home` | First slide |
| `End` | Step 1 of the last slide |
| 0 to 9 | Type a slide number |
| `Enter` | Step 1 of the slide that you typed |
| `o` | Overview of the slides. Only this window shows it. |
| `m` | Menu of the slides and their steps. Only this window shows it. |
| `b` | Black screen. The next key shows the slide again. |
| `d` | Code and charts in full color until the next step, in the two windows |
| `t` | Light or dark variant of the theme, in the two windows |
| `f` | Full screen on or off |
| `r` | Set the timer to 0:00 |
| `?`, `/` | The search of the keys and commands. Esc closes it. |
| Click or tap the right two thirds, or swipe left | Next step |
| Click or tap the left third, or swipe right | Previous step |

<!-- /keys -->

The timer starts at the first change of the step after the speaker view opens. A second `s`
shows the open speaker view again, and its timer continues.

### The time of the talk

The `duration` option of the deck gives the length of the talk in minutes. The speaker view
then shows the time left under the timer. The time left turns amber when the presenter is
more than one minute behind, and red after the end of the time.

Each step gets the same part of the time. The presenter is behind when the presenter used
more time than the steps before the current step get.

![The timer runs, the time left turns amber behind the pace, and red after the end](https://raw.githubusercontent.com/rellen/expresso/media/present-pace.gif)

## The handout view

The handout view shows one page for each step of each slide. A printer gets this view with
no key. In this view, only these keys operate, so the other keys scroll the pages:

<!-- keys handout -->

| Key | Action |
| --- | --- |
| `j` | Next step. The present view then shows it. |
| `k` | Previous step. The present view then shows it. |
| `p` | Present view |
| `a` | Every step, or the steps of the handout option. A print shows the same. |
| `?`, `/` | The search of the keys and commands. Esc closes it. |

<!-- /keys -->

![The handout view: three pages, one for each step, with the notes under each page](https://raw.githubusercontent.com/rellen/expresso/media/present-handout.png)

A slide can select the steps that get a page, with the forms of `at`:

```elixir
slide "overlays" do
  handout [3, :last]
  # ...
end
```

`handout :last` gives the last step only, and `handout :all` gives each step. `:last` can
also go in a list, such as `[2, :last]`. Write `handout :last` in the deck to give only the
last step of each slide that has no `handout` option. The handout view on a screen shows the
same pages as the paper. The speaker view still shows each step.

`a` shows each step of each slide, whatever the `handout` options select. A print or a PDF
from that window gets the same pages. A second `a` shows the selection again.

## The address

The address of the document holds the slide and the step, and it can hold these
parameters:

| Part | Example | Effect |
| --- | --- | --- |
| `#<slide>.<step>` | `deck.html#4.2` | Step 2 of slide 4. A reload shows the same step. |
| `?scheme=` | `deck.html?scheme=dark` | The `dark` or the `light` variant of a theme. See [Give a deck a light and a dark variant](../how-to/give-a-deck-two-variants.md). |
| `?duration=` | `deck.html?duration=15` | The length of the talk in minutes. It replaces the `duration` option of the deck. |
| `?all` | `deck.html?all` | The handout view with each step, as after `a`. |
| `?check` | `deck.html?check` | The layout check. See [the layout check](layout-check.md). |

A step that the slide does not have shows the nearest step of that slide, so an old link
still opens the right slide after the slide loses a step.

## The progress bar

A thin bar at the bottom of the present view shows the part of the deck that is done. Each
step of each slide counts one time. Write `progress false` in the deck to hide the bar at
the start. The key `g` can still show it.

![The bar at the bottom grows with each step](https://raw.githubusercontent.com/rellen/expresso/media/present-progress.gif)

## The slide numbers

Write `slide_numbers true` in the deck to show the slide numbers. The right corner at the
bottom then shows the number of the slide and the number of slides, such as `3 / 12`.
Slide 1 shows no number, because it is usually the title slide. The handout view and the
print show the numbers too.

![Slide 3 of 6, with the number in the right corner at the bottom](https://raw.githubusercontent.com/rellen/expresso/media/present-slide-numbers.png)

## The transitions and the morph

A move to a different slide in the present view fades the old slide out and the new slide
in. The `transition` option of the deck or of a slide sets a different kind, and a move
back plays the same kind in reverse. A move to a different step inside a slide uses the
animations of the overlays. See [the transition option](transition-option.md).

An element that two neighbor slides share moves from its place on one slide to its place
on the next slide. See [the morph option](morph-option.md).

The transitions need the View Transitions API of the browser. A browser
without it, and a user who asks for reduced motion, get an instant change. The speaker view
has no transitions.

## Accessibility

A screen reader reads the name of each slide when the presenter moves to it, such as
"Slide 2 of 3: A restart". It also reads the step at each move inside a slide. The views
are in a `main` landmark, and each slide is a group with the role description "slide". The
menu is a list of options that a screen reader reads. See
[The accessibility of a deck](accessibility.md).

## The custom properties of a theme

A theme can set these custom properties:

| Property | Effect |
| --- | --- |
| `--transition-dur` | The length of a transition. |
| `--slide-padding` | The space between the edge of a slide and its content. The default is `0 1rem`. |
| `--pace-behind-color`, `--pace-over-color` | The colors of the time left. |
| `--progress-color`, `--progress-height` | The color and the height of the progress bar. |
| `--slide-number-color`, `--slide-number-size` | The color and the size of the slide number. |
| `--slide-number-right`, `--slide-number-bottom` | The position of the slide number. |
| `--goto-color` | The color of a link of the `goto` option. |
| `--digits-color`, `--digits-background` | The colors of the slide number that the presenter types. |
