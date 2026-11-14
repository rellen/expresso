# The notes of the speaker

This document gives the design for the notes of the speaker: Markdown in a note, and a
note for some steps of a slide. The code contains this design. Issue #406 asked for it.
The document records ten decisions. Nine are settled, and decision 2 has a question for
the maintainer. Its last section, "The result", tells what changed during the work.

## The problem

The `notes` option of a slide was one string. The speaker view showed it as plain text,
and it showed the same note at each step of the slide. A slide with five steps then had
one long note, and the presenter had to find the part of the current step. Keynote and
PowerPoint take formatting in the notes, and reveal.js and Slidev take Markdown.

## The plan

1. The text of a note is Markdown. `Expresso.Notes.html/1` makes its HTML with MDEx.
2. The `note` entity of a slide gives a note for the steps of its `at` option.
   `Expresso.Element.Note` is its struct.
3. `Expresso.Overlay.Expand.slide/1` gives each note its step numbers. A note takes no
   step from the counter, and it adds no step to the slide.
4. The renderer writes the notes of each page of the handout view: the notes for each
   step, then the notes of the step of the page.
5. The presenter script puts a copy of the notes of the page of the current step into
   the speaker view.

## The decisions

1. **Markdown, from MDEx.** The maintainer made this decision. MDEx reads CommonMark and
   the extensions of GitHub, and it needs no parser of this project. The notes use the
   extensions for an address as a link and for text with a line through it.
2. **MDEx is not in a release, and the binary shows plain text.** MDEx is a NIF in Rust.
   RustlerPrecompiled gets its library from a release of MDEx on GitHub, for the computer
   that compiles. The ERTS of a Burrito binary for Linux uses musl, and the library for
   glibc and the library for musl both need `libgcc_s.so.1`. On a computer with glibc,
   the loader of musl then stops with `_dl_find_object: symbol not found`. A binary for
   macOS from a computer with Linux gets the library of Linux. The dependency therefore
   has `runtime: false`, so a release does not hold it, and `Expresso.Notes` calls MDEx
   only when it is available. Without MDEx, a note shows its text as you wrote it. The
   question for the maintainer is below.
3. **A line break stays, and HTML shows as text.** The notes were plain text with each
   line break. With the option `hardbreaks` of MDEx, a note that was correct before keeps
   its lines. With the option `escape`, a note with `<Enter>` keeps that text. A note
   needs no HTML, because Markdown gives each form that the issue named.
4. **An entity, and not a separator in the text.** `note "Ask the room.", at: 2` agrees
   with the DSL and with `Expresso.Builder`, and the compiler finds a step that the slide
   does not have. A line `---` between the notes of two steps is shorter, but the author
   must count the lines, and a note for two steps needs its text two times.
5. **The `at` option takes step numbers only.** A `:next` takes the value of the counter
   and adds 1 to it, so a note with `:next` adds a step with no change on the slide. The
   option takes the forms of the `handout` option.
6. **A note adds no step.** The steps of a slide come from the elements that the audience
   sees. A note for a step that the slide does not have is an error, as a label of such a
   step is.
7. **The `notes` option stays, and a `note` with no `at` is the same.** Each deck with
   notes continues to work. A `note` with no `at` lets you write a note near the element
   that it tells about.
8. **Each page holds its notes.** The document has one page for each step in the handout
   view, and the page of a step holds the notes for each step and the notes of its step.
   The speaker view shows a copy of the notes of the page of the current step. The script
   needs no list of the notes, and the handout view and the speaker view cannot disagree.
9. **Paper shows each note.** With `handout :last`, a slide has one page. That page also
   holds the notes of each earlier step with no page, under a label such as `Step 2`.
   The speaker view leaves those notes out, because they are not notes of the current
   step. The key `a` shows each page, and the earlier notes then do not show.
10. **A screen reader reads the notes of the current step.** The speaker view holds the
    notes as paragraphs and lists, with no live region. The presenter reads the notes when
    the presenter wants them, and a live region would read each note at each step.

### The question of decision 2

The binary and `mix expresso` write different HTML for a deck with notes. The test "writes
the same HTML as Expresso.main/2" of `test/release/` therefore gives `Expresso.main/2` the
setting `notes_markdown: false`. These are the alternatives:

| Alternative | Effect |
| --- | --- |
| MDEx with `runtime: false`, as the code is | Markdown with `mix expresso`. Plain text in the binary. |
| A parser in Elixir, such as Earmark | The same HTML in each place. One more dependency in the binary. The change is in `Expresso.Notes.html/1` and in `mix.exs`. |
| MDEx in the binary, with a library of `libgcc` for musl | Markdown in each place. The release must get the library of MDEx and of `libgcc` for each of its four targets. |

## The result

The code follows the plan, with these changes:

1. **The dependency has `runtime: false`.** The first build of the binary had MDEx, and
   each start wrote a warning that the library did not load. Decision 2 gives the cause.
2. **`elixirc_options: [no_warn_undefined: [MDEx]]`.** MDEx is not an application of
   Expresso, so the compiler gave a warning for the call. `Expresso.Notes` makes sure that
   the module is available.
3. **A check note.** `--check` tells when the notes show as plain text, so a user of the
   binary knows the cause.
4. **The speaker view takes a copy of the elements.** It took the text of the notes
   before. It now takes a copy of each note of the page, so the markup stays.

`docs/reference/note-element.md` gives the options, and
`docs/how-to/write-notes-for-the-speaker.md` gives the steps.
