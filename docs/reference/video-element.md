# The video element

The `video` element plays a WebM or an MP4 file in a slide. The document holds the file
one time, and the presenter plays it only in the present view.

```elixir
slide "demo" do
  video "demo/demo.webm" do
    title "The counter restarts"
    poster "demo/demo.png"
    width "60%"
  end
end
```

`Expresso.Builder` takes the same options, such as
`video("demo/demo.webm", title: "The counter restarts", poster: "demo/demo.png")`.

## The options

| Option | Value | Effect |
| --- | --- | --- |
| The first argument | The path of a `.webm` or a `.mp4` file, relative to [the root option](root-option.md) of the deck, or to the working directory of the command | The video. Required. |
| `title` | A string | The name of the video for a screen reader, and the text of the poster. Required. |
| `poster` | The path of an image | The image that shows on paper, in the handout view, in the speaker view, in the overview, in the menu and while the video loads. Required. |
| `width` | A width, such as `900px` or `60%` | The width of the video. The default is `80%`. |
| `aspect` | A ratio, such as `"4/3"` | The ratio of the width to the height. The default is `"16/9"`. |
| `loop` | `true` or `false` | Play the video again from the start at its end. The default is `true`. |
| `controls` | `true` or `false` | Show the controls of the browser, so the presenter can turn the sound on. The default is `false`. |
| `at`, `on`, `effect`, `speed`, `easing` | See [the overlay options](overlay-options.md) | The steps of the video, as for each other element. |
| `class` | CSS class names | See [the class option](class-option.md). |

The box of a video is the box of an embed. A deck can set `--embed-width` and
`--embed-aspect` in a rule of its CSS.

## When the video plays

| Place | Result |
| --- | --- |
| The present view, while the slide and the step of the video show | The video plays, with no sound. |
| A black screen, the menu or the overview | The video pauses, and it goes on from the same time after. |
| A move to another slide, and a move back | The video pauses, and it starts again from the start. |
| The speaker view, the handout view, the overview, the menu and paper | The poster shows. |

A browser starts a video with sound only after a click. Therefore the video has no sound,
and `controls true` lets the presenter turn the sound on.

## The document

The renderer writes each file one time, as a data URI, into the element
`expresso-videos`. Two video elements with the same file share it. Each copy of the slide
holds only a `video` element with `data-video`, the number of the file, and the poster
under it. The presenter gives the `video` element of the present view its source the first
time that it plays.

## The errors

The compiler gives an error for:

- a first argument that is not the path of a `.webm` or a `.mp4` file,
- a video with no `title` or no `poster`.

The renderer raises an `ArgumentError` for a video file or a poster that it cannot read.

For the steps, see [Show a video](../how-to/show-a-video.md).
