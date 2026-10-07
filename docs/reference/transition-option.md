# The transition option

The `transition` option gives the transition from one slide to the next in the present
view.

## Where you write it

| Place | Default | Effect |
| --- | --- | --- |
| The deck | `:fade` | The kind for each slide change of the deck. |
| A slide | the kind of the deck | The kind between this slide and the slide before, in the two directions. |

`Expresso.Builder` takes the same option, such as `deck(slides, transition: :slide)` and
`slide("second", transition: :zoom)`.

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

### A transition of the CSS of the deck

A rule in [the css option](css-option.md) for `html[data-transition="name"]` gives the
transition `:name`. Write hyphens in the CSS and underscores in the deck, as
`[data-transition="wipe-down"]` for `transition :wipe_down`.

| Selector | Animates |
| --- | --- |
| `html[data-transition="wipe-down"]::view-transition-old(slide)` | The slide that the presenter leaves. |
| `html[data-transition="wipe-down"]::view-transition-new(slide)` | The next slide. |
| `html[data-transition="wipe-down"][data-direction="back"]::view-transition-old(slide)` | The slide that the presenter leaves, on a move back. |
| `html[data-transition="wipe-down"][data-direction="back"]::view-transition-new(slide)` | The slide before, on a move back. |

- The theme gives each of the two pseudo-elements `--transition-dur` as its duration and
  `--ease` as its timing function. A rule of the deck can replace them.
- A pseudo-element without a rule of the deck keeps the fade of the browser.
- Without a rule for `[data-direction="back"]`, a move back plays the rules of a move
  forward.
- The compiler gives an error for a transition without a rule in the theme or in the CSS of
  the deck. The error gives the selector to write.
- The name has letters, digits and underscores only. The renderer writes each underscore as
  a hyphen.

For the steps and a complete deck, see
[Make a transition of your own](../how-to/add-transitions.md#make-a-transition-of-your-own).

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
