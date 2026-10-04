# CLAUDE.md

This file gives guidance to Claude Code when it works in this repository.

## Orientation

Expresso makes one HTML document from a deck. A browser then presents the deck.

Read these documents before you change the code:

- `docs/architecture.md` — the two input paths, the render pipeline, the templates, the
  elements, the DSL, the presenter and the build. Its section "Open work" gives the next
  items in the order of their value.
- `docs/overlays.md` — the design for overlays, which are the steps inside one slide. The
  code contains each part of the design. The document ends with six decisions, and
  each is settled.
- `docs/development.md` — how to get a toolchain, how to run the checks and how to look at
  a deck in a browser.
- `docs/typescript.md` — the plan for the presenter script in TypeScript, and the record
  of its result. The code contains this conversion.
- `docs/dim-state.md` — the plan for a dim state with a color for each role. The code does
  not contain this plan yet. The document ends with four decisions, and each is settled.

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
mix hex.audit
mix dialyzer
mix test
npm run check
npm test
mix test --only e2e
BURRITO_TARGET=linux_x86 MIX_ENV=prod mix release expresso_cli_app --overwrite
EXPRESSO_BINARY=burrito_out/expresso_cli_app_linux_x86 mix test --only release
```

Each command above passes at this time, and `mix check` passes as a whole. Keep them so. The
two `npm` commands need Node, and the hook runs `npm install`. `mix compile`
does not need Node. It needs Zig, because Zigler compiles the GIF encoder of `tools/` in
dev and in test.

`mix check` runs each command above, except the two `npm` commands. It runs the formatter
with `--check-formatted`. It makes the binary for the target of the computer, and it runs
the release tests with that binary. `.check.exs` gives the tools.

`mix test --only e2e` runs the browser tests of `test/e2e/`. They need Node, the Playwright
driver of `package.json` and Chromium. `mix test` excludes them. In a remote session, the
hook sets `EXPRESSO_CHROMIUM` to the Chromium of the container. `docs/development.md` gives
the details.

`mix test --only release` runs the tests of `test/release/`. They run the binary that
Burrito makes, and `EXPRESSO_BINARY` gives its path. `mix release` needs Zig, and the hook
installs it. `mix test` excludes these tests. `docs/development.md` gives the details.

`mix hex.audit` fails for a dependency with a security advisory or a retirement on Hex.
`mix deps.get` writes a warning for the same advisory, and the session start hook runs it,
so read its output. `docs/development.md` tells how to act on an advisory.

These results come from Erlang/OTP 29.1, Elixir 1.20.4, Node 24.20.0 and Zig 0.16.0, which
`.tool-versions` gives. The hook installs these versions, the Nix shell gives them, and the
workflow uses them. Therefore a command in a session gives the same result as a command on
a machine.

Do not change a version in `.tool-versions` or in `mix.exs` to make a command work. Four
places give the toolchain, and `docs/development.md` names each one. A change to one place
needs a change to the other three.

## Git

Do not commit to `main` and do not push to `main`. Make a branch, push the branch, and
open a pull request. The maintainer merges it.

`.github/workflows/check.yml` runs each command of "Build and test" for a pull request, in
parallel jobs. Do not wait for that result. Run the commands in "Build and test"
before each commit, because the session gives the same versions as the workflow. Tell the
maintainer in the pull request which commands you ran.

The jobs run on the versions of `.tool-versions`. The last job, `Erlang/OTP 29, Elixir 1.20,
Node 24`, needs each other job, and it fails when one of them fails. This job must pass.

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

### Mannered prose

Mannered prose puts a metaphor or a flourish where a direct statement can go. The reader
must then find the meaning of the phrase, and the metaphor can bring a meaning that the
writer did not intend.

Say what you mean. When a literal phrase is available, use it.

| Do not write | Write |
| --- | --- |
| a dial worth turning | a parameter to change |
| this check earns its keep | this check finds real defects |
| the watch mode sits on top of the renderer | the watch mode calls the renderer |
| `parse/1` gives a tuple | `parse/1` returns a tuple |
| the time of the change of the file | the time when the file changed |
| a person, the person who runs the command | you, the user, the presenter |

- Use `returns` for the result of a function. Use `gives` only for a thing that the user or
  a tool supplies, such as an option.
- Do not put an `of` phrase after an `of` phrase. Change the second phrase to a verb or to
  a possessive.
- Name the actor. Write `you` in an instruction, `the user` for a user of Expresso, and
  `the presenter` for the user who gives the presentation.

### Formatting

Write for two readers: a developer who uses Expresso to make a deck, and a developer who
works on the code of Expresso. Put the fact that the reader needs first.

- Start a `@moduledoc`, a `@doc` or a section with one sentence that tells its purpose.
- Use a numbered list for steps that occur in sequence.
- Use a bulleted list for three or more items that have no sequence.
- Use a table to compare items on the same attributes.
- Use a code block for a command or an example that the reader can copy.
- Put a file name, a command, an option and an identifier in backticks.
- Use a heading for each topic that a reader can look for.
- Use bold text only for a term at the point where you define it.
