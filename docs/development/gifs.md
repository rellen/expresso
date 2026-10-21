# Record the GIFs and the stills of the examples

The how-to guides and the reference pages show a GIF or a still of each example deck of
`examples/animations/`, and each how-to guide shows at least one. `docs/reference/presenter.md`
and `docs/how-to/present-a-deck.md` show a GIF or a still of each example deck of
`examples/presenter/`. "The gallery" of `docs/reference/theme-option.md`
shows a still of `examples/themes/showcase.exs` for each built-in theme.
`mix expresso.gifs` records them:

```sh
mix expresso.gifs                        # each example, into _build/gifs
mix expresso.gifs /tmp/gifs overlay-at   # one example, into /tmp/gifs
```

The task renders each example deck to an HTML file, and `Expresso.Recorder` records it.
Two example decks draw a graph, so the task needs Graphviz and D2. `graph-tools.md` tells
how to install them.
`Expresso.Gif` then encodes the frames as a GIF. The task and the two modules are in
`tools/`, so only dev and test compile them, and the binary does not hold them. The list of
the examples is in `Mix.Tasks.Expresso.Gifs`. An example has:

- a name, which gives the name of the file;
- a deck file;
- an address after the path of the HTML file, such as `?speaker#2.1`, for a view or a
  position;
- actions, which are keys, or a move of the clock of the page, such as
  `{:advance, 90_000}`, for the timer of the speaker view;
- `still: true` for a PNG of the page after the actions, in place of a GIF;
- a height of the picture, in the layout of a window of 1280 by 720 pixels, so a still of
  the handout view can show several pages;
- a theme, which replaces the `theme` option of the deck. The task makes one example
  with each built-in theme for the deck of the themes. That deck uses `Expresso.Builder`,
  so the task can evaluate it again for each theme.

The recorder opens each document in Chromium with `playwright_ex`, does the actions, and
takes a screenshot of each frame. Before the first frame, it moves each animation of the
load to its end. After a key, it pauses each animation of the page, and it moves the
animations to the time of each frame. The clock of the page is fixed, and a move of the
clock sets it to a later time. The frames therefore do not depend on the speed or the time
of the computer, and two runs write the same files. A still is the last frame, as a PNG.

Chromium can refuse a screenshot with the message `Unable to capture screenshot`. In
October 2026, this occurred in 3 of approximately 22 runs of the job `gifs`, but not on a
computer with Chromium 141. Each time, the refused screenshot was the first screenshot of a
new page. In one run, a second screenshot two animation frames later was also refused.

Therefore the recorder records the whole example again in a new page, after one second, up
to three runs in total. The frames are the same in each run, so the GIF does not change. The
task writes a line for each new run, and a different error or a third refusal stops the
task.

`Expresso.Gif` encodes the frames with a NIF in Zig, `Expresso.Gif.Nif`, and it needs no
program such as ffmpeg. These are the steps:

1. A frame that is the same as the frame before it adds its delay to that frame.
2. The first frame holds each pixel. Each later frame holds only the rectangle of the
   pixels that change, and an unchanged pixel in it is transparent.
3. Median cut makes a palette for each frame from its exact colors. A frame with 256
   colors or fewer keeps its exact colors.
4. LZW compresses the frame. The frames encode in parallel, on dirty CPU schedulers.

`test/expresso/gif_test.exs` decodes each GIF with the decoder of
`test/support/gif_decoder.ex`, and it compares the result with the frames. Draft pull
request #114 compares this encoder with an encoder in Elixir, Rust, Vix, ffmpeg and gifski.

The job `gifs` of the workflow records the files for each pull request, and the artifact
`gifs` holds them. After a push to main, the job `media` replaces the branch `media` with
one commit of the new files, when each check succeeded. The guides and the README show each
file from that branch, so the history of main holds no GIF.

To add an example of a guide, write a deck in `examples/animations/`, and add it with its
keys to the list of the task. Then show its code and its GIF in a guide. To add an example
of the presenter, write a deck in `examples/presenter/`, or use one of the decks there,
and add the example to the list. Then show its file in one of the two presenter pages.
`test/expresso/examples_test.exs` makes sure that a how-to guide shows the code of each
deck of the guides as it is in the file, that the guides show each of their files, that
each how-to guide shows at least one file, and that the README shows no file that the task
does not record.
