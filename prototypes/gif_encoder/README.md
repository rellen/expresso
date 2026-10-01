# GIF encoder prototype

This prototype compares encoders that can replace gifenc in the GIF recorder of Expresso.
It answers decision 7 of `docs/research/elixir-presenter-report.md` in part: can the
recorder encode its GIFs from Elixir, and at what cost?

It is a separate Mix project. The checks and the workflow of Expresso do not compile it.

## The interface

`GifEncoder` is a behaviour with one callback:

```elixir
@callback encode([%{png: binary(), delay: non_neg_integer()}], keyword()) ::
            {:ok, binary()} | {:error, term()}
```

A frame is a PNG image from Chromium and the time that the GIF shows it, in milliseconds.
`GifEncoder.encode(frames, encoder: GifEncoder.Zig)` selects an encoder. The recorder
needs no other function.

An encoder of one frame uses `GifEncoder.PerFrame` and defines `encode_frame/2`. That
function returns the size, the palette, the minimum code size and the LZW data of the
frame. `GifEncoder.PerFrame` then encodes the frames in parallel, one task for each
frame. `GifEncoder.Container` writes the GIF around them. An encoder of a whole GIF
implements `encode/2` directly.

| Encoder | Kind | Method | What it needs |
| --- | --- | --- | --- |
| `GifEncoder.Elixir` | One frame | Median cut on the exact colors, then LZW, in Elixir. | Nothing. |
| `GifEncoder.Zig` | One frame | The same algorithm, in a Zig NIF (Zigler 0.16). | Zig 0.16 to compile. |
| `GifEncoder.Rust` | One frame | A Rust NIF (Rustler 0.38): the `png`, `color_quant` (NeuQuant) and `weezl` crates. | Rust and cargo to compile. |
| `GifEncoder.Vix` | Whole GIF | libvips 8.18 through Vix 0.42: cgif and libimagequant. | The libvips binary that Vix downloads. |
| `GifEncoder.Ffmpeg` | Whole GIF | The `ffmpeg` command: `palettegen` and `paletteuse` for each frame. | ffmpeg 6. |
| `GifEncoder.Gifski` | Whole GIF | The `gifski` command 1.34: libimagequant. | gifski. Its license is AGPL 3.0. |

The four NIF and library encoders run on dirty CPU schedulers or in their own threads, so
they do not block the schedulers of the BEAM.

## Run it

You need the toolchain of Expresso, cargo, ffmpeg and gifski:

```sh
cargo install gifski
cd prototypes/gif_encoder
mix deps.get
ZIG_EXECUTABLE_PATH=/opt/zig/zig mix test
```

`ZIG_EXECUTABLE_PATH` gives the Zig of the toolchain. Without it, run `mix zig.get` first.
`FFMPEG` and `GIFSKI` give the paths of the two commands. A test of a command that is not
available does not run.

To compare the encoders on the frames of each example of Expresso:

1. Dump the frames: copy `assets/gifs/record.ts`, and make the copy write each frame to
   `<name>/NNN.png` and the delays to `<name>/delays.json` in place of the GIF.
2. Encode the frames with gifenc, for the baseline:

   ```sh
   node scripts/gifenc.mjs <frames> <gifenc output>
   ```

3. Run the comparison:

   ```sh
   mix gif_encoder.bench <frames> --gifenc <gifenc output> --gifenc-ms <time from step 2>
   ```

`test/fixtures` holds the 19 frames of the example `overlay-at`.

## The results

The examples of Expresso give 25 animations and 550 frames of 800 by 450 pixels. The
computer had 4 cores. A time is the time to encode each animation, after one run to warm
up. "One core" runs one task at a time.

| Encoder | All cores | One core | Size | Mean PSNR | Min PSNR |
| --- | --- | --- | --- | --- | --- |
| Elixir | 51.24 s | 147.58 s | 5.39 MB | 91.5 dB | 45.2 dB |
| Zig | 2.08 s | 6.51 s | 5.39 MB | 91.6 dB | 47.3 dB |
| Rust | 5.04 s | 16.96 s | 5.11 MB | 63.4 dB | 44.2 dB |
| Vix | 21.61 s | - | 2.40 MB | 80.7 dB | 35.8 dB |
| Ffmpeg | 10.83 s | - | 4.68 MB | 91.5 dB | 48.9 dB |
| Gifski | 41.57 s | - | 2.69 MB | 59.0 dB | 47.8 dB |
| gifenc (Node, today) | 8.95 s | 8.95 s | 4.02 MB | 56.1 dB | 41.8 dB |

`GifEncoder.Quality` measures the PSNR. libvips decodes each GIF, and the measure
compares each source frame with the page that the GIF shows at the start time of the
frame. A larger value is better. An identical frame gives 99 dB, so a mean near 91 dB
tells that most frames have 256 colors or fewer and keep their exact colors. Each
encoder keeps the duration of each animation to the millisecond.

## What the results show

- **Zig is the fastest.** It is 4.3 times faster than gifenc on 4 cores, and 1.4 times
  faster on one core. It runs the same algorithm as the Elixir encoder, approximately 25
  times faster.
- **Pure Elixir is too slow.** It needs 51 s on 4 cores, 5.7 times the time of gifenc.
  A frame with many colors, such as a frame of a transition, is the slowest part.
- **Vix and gifski make the smallest files**, 40% and 33% smaller than gifenc. After
  the first frame, they write only the rectangle of the pixels that change, with the
  other pixels transparent, and they merge identical frames. In `overlay-at`, Vix
  writes 1 full frame of 17, and gifski 2 of 32. The other encoders write each frame
  in full.
- **ffmpeg gives the best minimum quality**, 48.9 dB. It is a little slower than gifenc.
- **Vix has the lowest minimum quality**, 35.8 dB, on the gradient of `overlay-diagram`
  only. Each other animation is above 40 dB.
- **NeuQuant (Rust) and gifenc** always make 256 colors, so they lose the exact colors
  of a frame with fewer colors. Median cut keeps them.

## What the prototype found

- **ffmpeg rounds each delay to 40 ms by default.** The image demuxer reads a PNG at 25
  frames a second. A delay of 900 ms became 920 ms, and the animation drifted. The option
  `framerate 100` for each file of the concat list fixes it. The option `-final_delay`
  gives the delay of the last frame, because the demuxer ignores it.
- **gifski takes a constant frame rate only.** The encoder writes each frame as many
  times as its delay needs, at 50 frames a second, with hard links. gifski merges most of
  the copies again.
- **cgif merges identical frames**, so a GIF of Vix can have fewer pages than frames.
  The quality measure therefore compares frames at their start times, not page by page.
- **Each encoder of a whole GIF reads files or a command.** ffmpeg and gifski need a
  temporary directory for each GIF.

## Recommendation

Use `GifEncoder.Zig` if the recorder moves to Elixir:

- It is the fastest, and its quality is better than that of gifenc.
- Zig 0.16 is already in the toolchain of Expresso, for Burrito. Zigler adds a Hex
  dependency, and no new tool.
- `GifEncoder.Elixir` runs the same algorithm, so it is a reference for the tests and a
  fallback with no NIF.

Before the recorder uses it, add the frame difference of cgif to `GifEncoder.Container`.
The container then writes only the rectangle of the pixels that change, as Vix and gifski
do. The results of Vix suggest that this halves the size of the GIFs of each encoder of
one frame. The prototype did not measure that change.

ffmpeg is the best choice that shells out. Its quality is the best, and its time is close
to that of gifenc. It is a system dependency, so each of the four places that give the
toolchain must give it too. `docs/development.md` names the four places.

Do not use the Rust encoder: Rust is a new toolchain, and Zig is faster here. Do not
link gifski into a NIF, because of its license.
