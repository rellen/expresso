# A video file or a sound file next to the document

This document gives the design for a `video` and an `audio` element that keep their file
next to the document, in place of a data URI in the document. The code contains this
design. Issue #317 asked for it. The document records ten decisions, and each is settled.
Its section "The result" tells what changed during the work. A later change gave the
`image` element the same option, and it gave the deck an option for the default. See
"A later change: an image, and an option of the deck".

## The problem

The document of a deck holds each video file and each sound file as a data URI, in a JSON
element such as `expresso-videos`. One file is easy to send and to keep. For a deck on a
web host, the data URI has three costs:

1. The JSON elements come before the presenter script, so the first slide waits for each
   file. A talk with a recording of 50 MB makes the first slide wait for 50 MB.
2. The browser keeps the file in memory as text. It cannot go to a time of the file
   before the whole file arrives.
3. A change of one word of the deck changes the document, so a viewer gets each file
   again.

## The plan

1. The `video` and the `audio` elements get the option `external true`.
2. The render makes a copy of the file for a directory next to the output file, such as
   `talk_files/` for `talk.html`. The name of the copy holds a hash of its content.
3. The JSON element holds the relative address of the copy in place of the data URI. The
   presenter script puts each value of the element into `src`, so it needs no change.
4. Each code that writes a document also writes the copies: `mix expresso`, the binary,
   the watch mode, `--check` and the export.

## The decisions

Each decision is settled.

1. **An option of the element, and not of the deck.** The maintainer made this decision.
   The common case is one long recording in a talk. The default stays `false`, so a deck
   stays one file. A deck option can set the default later.
2. **A copy, and not an address that the user gives.** The maintainer made this decision.
   The render reads the file, gives it a name from its content, and writes it next to the
   document. The watch mode and `--check` then work with no network.
3. **The name holds eight digits of the SHA-256 of the content.** A host can keep the file
   in its cache for a long time, and a changed file gets a new name. Two elements with
   the same file get the same name, so they share one copy.
4. **The directory has the name of the document, and `_files`.** `talk_files/` is next to
   `talk.html`, so two decks in one directory keep their files apart. A browser uses the
   same name when it saves a page.
5. **The render keeps the copies in the process dictionary.** `Expresso.Deck.render/1`
   returns the text of the document, and each caller writes that text. A second return
   value changes each caller and each test. `Expresso.MediaFiles.collect/2` runs a render
   and returns its copies, as `Expresso.DeckFile.track/1` returns the paths of a render.
6. **A render with no directory is an error.** With `-` as the output, the document goes
   to the standard output, and the copies have no place. The render then raises an
   `ArgumentError` that names the file and the option, as it does for a file that it
   cannot read.
7. **The file goes through `Expresso.DeckFile`, as before.** The watch mode thus renders
   the deck again after a change of the file, and a missing file still stops the render
   with its path.
8. **The poster and the captions stay data URIs.** They are small, and each copy of a
   slide in the handout view and in the menu shows the poster.
9. **The watch server sends the copies from its private directory.** The server already
   sends the files of that directory. A render writes each copy there before the
   document, so the document never names a file that the server does not have.
10. **Each tool writes the copies next to its own document.** `--check` and the export
    open a private copy of the document in a browser. They write the copies into that
    private directory, so the browser plays the same files.

## The result

The code follows the plan, with these changes:

1. **The watch server has its own module for a range.** A browser asks for a part of a
   video file. `mod_range` of OTP answers with the header `Content-Range: bytes=2-5/10`,
   and the correct form is `bytes 2-5/10`. Chrome then did not play the video.
   `Expresso.Watch.Range` answers a request for one range with the correct header, so a
   video in the watch mode can go to a time.
2. **The key of an element for its number is its file and its option.** Two elements with
   the same file and `external true` share one copy. An element with the option and one
   with no option have a source each, because one is an address and one is a data URI.
3. **With no output file, the directory has the name of the input file.** The watch mode
   and `--check` can run with no output file. The address in the document then starts
   with `talk_files/` for `talk.exs`, and the standard input gives `deck_files/`.
4. **A copy that is already there is not written again.** Its name holds the hash of its
   content, so a file with that name has that content.
5. **The schema of the script takes a relative address.** The lists `written_videos` and
   `written_audios` took only a data URI. They now also take a relative path with the
   extension of a video file or of a sound file, and no address of a different host.

`docs/reference/video-element.md` and `docs/reference/audio-element.md` give the option,
and `docs/how-to/show-a-video.md` has the section "Keep a long video next to the
document".

### A later change to the first cost

The first cost of "The problem" was not correct. A measurement for issue #568 showed that
the first slide did not wait for each file: it showed after approximately 2 s. The
presenter waited, so the deck did not answer a key before the browser received each file.

The JSON elements with the files now come after the presenter script, and the presenter
starts before the browser received them. A deck with a video in the document then answers
a key at the time of its first slide. `external true` still has the second cost and the
third cost as its reasons, and the document with such an element is still much smaller.

### A later change: an image, and an option of the deck

Issue #564 asked for the same option on the `image` element. The maintainer made these
decisions on 2026-11-15:

1. **The `image` element takes `external true`.** `Expresso.Image.source!/2` gives the
   bytes to `Expresso.MediaFiles.put/3`, and each `img` element holds the address of the
   copy. Each view of a slide has the same address, so the browser gets the file one time.
2. **The deck takes the `external` option.** It is the default of each `image`, `video`
   and `audio` element. This replaces decision 1 for a deck with many files. An element
   has no default of its own, so `external false` on an element keeps its file in the
   document. `Expresso.Media.external/1` gives each element the value before the render.
3. **An image has no `loading="lazy"`.** The maintainer asked for a test in a browser
   first, and for no attribute if the export or `--check` did not work with it. The table
   gives the results.
4. **The other images stay data URIs:** the background of a slide, the image of a node of
   a tree, the fallback image of an embed, an image inside an SVG, and the poster of a
   video. Each one needs a change of its own.

The test of `loading="lazy"` used a deck of four slides with one image each, and a server
that sent an image after 400 ms:

| Measurement | With no attribute | With `loading="lazy"` |
| --- | --- | --- |
| The images that the browser asked for at the load | 4 of 4 | 1 of 4 |
| The image of slide 2 at the time when slide 2 showed | Complete | Not complete. It showed 400 ms later. |
| `--pdf` and `--png`, with four images of 10 MB | Each page had its image. | Each page had its image. |
| `--check=browser`, with an image that is 787 px too tall | It found the problem. | It found no problem. |

The layout check measures a slide before the browser has the image, so an image with no
size gives a wrong result. The attribute also showed an image late during the talk. A
later change can add the attribute, with two more parts: the presenter script must ask
for the images of the next slide, and the check must wait for each image.

With no attribute, the browser asks for each image when it loads the document. The first
slide does not wait for them, and the host can keep each one in its cache.

## The limits

- The render does not remove an old copy. After a change of the file, the directory holds
  the old copy and the new copy.
- A document with such an element is not one file. Send the directory with it.
- The speaker view and the handout view do not play a video, so they get no file.
- The browser asks for each image with `external true` when it loads the document, also
  for an image of a slide that the viewer does not go to.
