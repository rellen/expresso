# The audio element

The `audio` element plays a sound file in a slide. The document holds each file one time,
and the sound plays in the present view at the steps of the element.

```elixir
slide "the signal" do
  audio "chime.ogg" do
    title "The chime of a machine that stops"
    at from: 2
  end
end
```

`Expresso.Builder` takes the same options, such as
`audio("chime.ogg", title: "The chime", loop: true)`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | The path of a `.mp3`, `.m4a`, `.ogg`, `.oga` or `.wav` file | The sound. A path is relative to [the root option](root-option.md) of the deck, or to the working directory of the command. |
| `title` | A string, required | The name of the sound for a screen reader. The handout view and paper show it with a note symbol. |
| `loop` | `true` or `false` | Play the sound again from the start at its end. The default is `false`. |
| `controls` | `true` or `false` | Show the controls of the browser on the slide. The default is `false`. |
| `class` | CSS class names | See [the class option](class-option.md). |

The element also takes the overlay options, such as `at` and `effect`. See
[the overlay options](overlay-options.md).

The compiler gives an error for a path with a different extension and for an address. The
render gives an error for a file that it cannot read.

## When the sound plays

| View | The sound |
| --- | --- |
| The present view | The sound plays while its slide shows and the element shows at the current step. It starts from the start each time that its slide shows. |
| A black screen, the menu, the overview | The sound pauses. It goes on from the same time when the slide shows again. |
| The speaker view, the handout view and paper | No sound plays. The handout view and paper show the title with a note symbol. |

A browser plays a sound only after the first key or click of the presenter in the document.
A sound of the first slide therefore starts at the first key that changes the step, the
view or the screen. A sound on a later slide starts when its step shows.

## The controls

Without `controls`, the present view shows nothing in the place of the element. With
`controls true`, the slide shows the controls of the browser. The sound still plays at its
step, and the presenter can pause it, play it again or change its volume. A click on the
controls goes to the controls, and not to the presenter.

## The file

The document holds each file one time, as a data URI, so a long sound makes a large
document. Two elements with the same path share the file. A short sound in the Ogg format
is the smallest, and an MP3 file plays in each browser. The watch mode renders the deck
again after a change to the file.
