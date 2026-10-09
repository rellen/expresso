# Play a sound

This guide shows how to play a sound file in a slide, such as a signal or a short clip of
speech. For each option, see [The audio element](../reference/audio-element.md).

## Play a sound with controls

Write an `audio` element with the path of a sound file and a `title`. The sound plays while
its slide shows. The `controls` option shows the controls of the browser, so you can pause
the sound or play it again:

```elixir
defmodule Examples.Audio do
  use Expresso

  slide "the signal" do
    heading "The signal"

    text_box do
      text_area do
        text "Each machine of the line plays this chime when it stops."
      end
    end

    audio "examples/animations/chime.ogg" do
      title "The chime of a machine that stops"
      controls true
    end
  end
end

Examples.Audio
```

![The text of the slide, and the controls of the sound at the bottom](https://raw.githubusercontent.com/rellen/expresso/media/audio.png)

A browser plays a sound only after the first key or click in the document. A sound on the
first slide therefore starts at the first key.

## Start a sound at a step

Give the element an `at` option. Without `controls`, the slide shows nothing in the place
of the sound, so the sound and the text of the same step start together:

```elixir
defmodule Examples.AudioAt do
  use Expresso

  slide "the stop" do
    heading "The stop"

    text_box do
      text_area do
        text "The line runs."
      end
    end

    text_box do
      at from: 2

      text_area do
        text "A machine stops, and the chime plays."
      end
    end

    audio "examples/animations/chime.ogg" do
      at from: 2
      title "The chime of a machine that stops"
    end
  end
end

Examples.AudioAt
```

![The second text shows at step 2, when the chime plays](https://raw.githubusercontent.com/rellen/expresso/media/audio-at.gif)

## Show the sound in the handout view

The handout view and paper cannot play a sound. Each of their pages shows the title of the
sound with a note symbol. Press `p` to see the handout view:

```elixir
defmodule Examples.AudioHandout do
  use Expresso

  slide "the signal" do
    heading "The signal"
    notes "Play the chime, then ask what it means."

    audio "examples/animations/chime.ogg" do
      title "The chime of a machine that stops"
    end
  end
end

Examples.AudioHandout
```

![The page of the handout view shows the title of the chime and the notes](https://raw.githubusercontent.com/rellen/expresso/media/audio-handout.png)

## Make a small sound file

The document holds each sound file as a data URI, so a long or a large file makes a large
document. Use these steps to make a small file from a recording, such as `clip.wav`:

1. Cut the sound to the part that you need, and make it one channel:

   ```sh
   ffmpeg -i clip.wav -ss 0 -t 5 -ac 1 -c:a libvorbis -q:a 2 clip.ogg
   ```

2. Make an MP3 file in place of the Ogg file if a browser of the talk cannot play Ogg:

   ```sh
   ffmpeg -i clip.wav -ss 0 -t 5 -ac 1 -b:a 64k clip.mp3
   ```
