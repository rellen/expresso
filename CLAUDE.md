# CLAUDE.md

This file gives guidance to Claude Code when it works in this repository.

## Orientation

Expresso makes one HTML document from a deck. A browser then presents the deck.

Read these documents before you change the code:

- `docs/architecture.md` — the two input paths, the render pipeline, the templates, the
  elements, the DSL, the presenter and the build. It also lists the open work.
- `docs/overlays.md` — the design for overlays, which are the steps inside one slide. The
  code does not contain this design yet. The document ends with four open decisions.
- `docs/development.md` — how to get a toolchain, how to run the checks and how to look at
  a deck in a browser.

## Build and test

A remote session has no Elixir. The hook `.claude/hooks/session-start.sh` installs a
toolchain at the start of the session. Run it by hand if a command reports that `mix` is
not present. `docs/development.md` gives the details.

Run these commands before each commit:

```sh
mix compile --warnings-as-errors
mix format
mix credo
mix sobelow --exit --skip
mix dialyzer
mix test
```

`mix credo`, `mix sobelow`, `mix format` and `mix test` pass at this time. Keep them so.
`mix doctor` does not pass, because the doc coverage and the spec coverage are near 50
percent.

Do not change a version in `.tool-versions` or in `mix.exs` to make a command work. The
container of a remote session uses different versions, and `docs/development.md` tells you
why.

## Git

Do not commit to `main` and do not push to `main`. Make a branch, push the branch, and
open a pull request. The maintainer merges it.

The repository has no continuous integration. No check runs on a pull request. Therefore
the commands in "Build and test" are the only gate, and you must run them before each
commit. Tell the maintainer in the pull request which commands you ran.

## Commit messages

Use the Conventional Commits 1.0.0 specification. See https://www.conventionalcommits.org/en/v1.0.0/.

Write each commit message in this structure:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Use one of these types:

- `feat` — the change adds a feature.
- `fix` — the change corrects a defect.
- `docs` — the change affects documentation only.
- `style` — the change affects layout or format only. The behavior stays the same.
- `refactor` — the change alters structure. The behavior stays the same.
- `perf` — the change improves performance.
- `test` — the change adds or corrects a test.
- `build` — the change affects the build system, the dependencies or the toolchain.
- `ci` — the change affects the continuous integration configuration.
- `chore` — the change does not agree with the other types.

Obey these rules for the subject line:

- Put a colon and one space after the type.
- Add a scope only when the scope makes the change more clear.
- Put the scope in parentheses. Example: `fix(renderer): ...`.
- Start the description with a lowercase letter.
- Do not put a period at the end of the description.
- Write the description in the imperative mood. Write `add a slide template`. Do not write `added a slide template`.

Obey these rules for a breaking change:

- Put a `!` before the colon. Example: `feat(dsl)!: replace the deck macro`.
- Add a `BREAKING CHANGE:` footer. In the footer, tell the user what to do.

Put one blank line between the subject, the body and the footers.

The commits before this file do not obey this specification. Do not change those commits.

## Prose style

Write English prose in Simplified Technical English (ASD-STE100, Issue 9).

Apply this style to:

- Commit messages.
- Pull request titles and descriptions.
- Code comments.
- `@doc` and `@moduledoc` text.
- Markdown files.

Do not apply this style to:

- Code, identifiers and configuration values.
- Text that you quote from a tool, a log or a third party.

ASD-STE100 has two parts. Part 1 gives 53 writing rules. Part 2 gives a dictionary of
approximately 900 approved words. You can get the specification at no cost from
https://www.asd-ste100.org.

### Words

- Use one word for one meaning.
- Use the same word each time you refer to the same thing.
- Keep each word in one part of speech. The word `oil` is a noun. Write `Apply oil to the valve`. Do not write `Oil the valve`.
- Prefer the approved word. Write `make sure`. Do not write `verify`, `check`, `confirm` or `ensure`.
- Use American spelling.
- Do not put more than three nouns in a row.
- Do not use slang or jargon.

ASD-STE100 lets a project approve its own technical names and technical verbs. The
terms of Elixir, of the BEAM and of this build are approved technical words here. Examples
are `struct`, `macro`, `dependency`, `lockfile`, `compile` and `release`.

### Verbs

- Use the active voice in an instruction.
- Use the passive voice in descriptive text only when the actor is unknown or is not important.
- Use only these verb forms: the infinitive, the imperative, the simple present, the simple past, the simple future, and the past participle as an adjective.
- Do not use the present perfect. Write `we removed the dependency`. Do not write `we have removed the dependency`.
- Use an `-ing` form only as a technical noun, or as a modifier in a technical name.

### Sentences

- Write no more than 20 words in an instruction.
- Write no more than 25 words in a descriptive sentence.
- Give one instruction in one sentence.
- Keep all the necessary words. Do not remove an article, a subject or a verb to make a sentence short.

### Paragraphs

- Write no more than six sentences in a paragraph.
- Write about one topic in one paragraph.
- Use a vertical list when the material is complex.
