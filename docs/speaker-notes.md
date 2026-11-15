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
2. **MDEx is in a release, and the binary gets the library for its target.** MDEx is a
   NIF in Rust. RustlerPrecompiled gets its library from a release of MDEx on GitHub, for
   the computer that compiles. That library does not load in a Burrito binary: the ERTS of
   a binary for Linux uses musl, and a binary for macOS from a computer with Linux gets the
   library of Linux. The step `Expresso.Release.MDExLibrary` of the release therefore puts
   the library for the target into each binary. `Expresso.Notes` calls MDEx only when it
   is available, and without MDEx a note shows its text as you wrote it. The alternatives
   are below.
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

### The alternatives of decision 2

The first code had MDEx with `runtime: false`, so a release did not hold it. The binary
and `mix expresso` then wrote different HTML for a deck with notes. These were the
alternatives:

| Alternative | Effect |
| --- | --- |
| MDEx with `runtime: false` | Markdown with `mix expresso`. Plain text in the binary. |
| A parser in Elixir | The same HTML in each place. Earmark is retired on Hex. EarmarkParser returns a tree and no HTML, so Expresso must make the HTML. |
| MDEx in the binary | Markdown in each place. The release must get the library of MDEx for each of its four targets, and an unwinder for musl. |

The maintainer asked for a test of the third alternative. The test succeeded, and the
code has that alternative. `docs/development/release.md` tells how the library loads.

## The result

The code follows the plan, with these changes:

1. **The dependency had `runtime: false` at first.** The first build of the binary had
   MDEx, and each start wrote a warning that the library did not load. The dependency
   then got `runtime: false`, and the binary showed plain text. Item 5 gives the change
   after that.
2. **`elixirc_options: [no_warn_undefined: [MDEx]]`.** With `runtime: false`, MDEx was not
   an application of Expresso, so the compiler gave a warning for the call. Item 5 removed
   the setting.
3. **A check note.** `--check` tells when the notes show as plain text, so a user of a
   release where the library does not load knows the cause.
4. **The speaker view takes a copy of the elements.** It took the text of the notes
   before. It now takes a copy of each note of the page, so the markup stays.

5. **The binary holds MDEx.** `Expresso.Release.MDExLibrary` is a step of Burrito. It puts
   the library of MDEx for the target into each binary. For Linux, it also changes two
   entries of the library, and it builds an unwinder with Zig. The dependency has no
   `runtime: false` now, and the binary and `mix expresso` write the same HTML. The binary
   for macOS has no test, because no job of the workflow makes it.

`docs/reference/note-element.md` gives the options, and
`docs/how-to/write-notes-for-the-speaker.md` gives the steps.
