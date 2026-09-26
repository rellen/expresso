# The transition option

The `transition` option gives the transition from one slide to the next in the present
view.

## Where you write it

| Place | Default | Effect |
| --- | --- | --- |
| The deck | `:fade` | The kind for each slide change of the deck. |
| A slide | the kind of the deck | The kind between this slide and the slide before, in the two directions. |

A deck from the imperative API gives the same values in the metadata: `:transition` in the
metadata of the deck, and `:transition` in the metadata of a slide.

## The kinds

### `:fade`

The slide before fades out, and the next slide fades in. The direction has no effect.

![A fade from one slide to the next and back](https://raw.githubusercontent.com/rellen/expresso/media/transition-fade.gif)

### `:slide`

A move forward pushes the next slide in from the right. A move back pushes the slide before
in from the left.

![A slide to the next slide and back](https://raw.githubusercontent.com/rellen/expresso/media/transition-slide.gif)

### `:zoom`

A move forward grows the next slide from the center while the slide before fades out. A move
back shrinks the slide that it leaves while the slide before fades in.

![A zoom to the next slide and back](https://raw.githubusercontent.com/rellen/expresso/media/transition-zoom.gif)

### `:none`

The next slide shows at once.

![An instant change to the next slide and back](https://raw.githubusercontent.com/rellen/expresso/media/transition-none.gif)

## Rules

- Only a change of slide in the present view has a transition. A change of the step keeps the
  animations of the overlays.
- A black screen, the overview, the list of keys, the handout view and the speaker view have
  no transition.
- A transition belongs to the border between two slides. The slide with the higher number
  gives the kind in the two directions. A jump, such as `Home`, uses the kind of the slide
  with the higher number of the two.
- The browser must have the View Transitions API. A browser without it shows the next slide at
  once.
- A reader who asks for reduced motion gets no transition.
- A theme can set `--transition-dur`. The default is 400 ms. The `speed` option of the
  overlays does not change it.
