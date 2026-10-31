# The dependencies

This page tells you how to act on an advisory, how to update a dependency and how to update the icons.

## The audit of the dependencies

`mix hex.audit` fails for a dependency with a security advisory or a retirement on Hex.
Hex 2.5 added the advisories to this task, and they come from the same source as the
warnings of `mix deps.get`. The job `lint` runs it for each pull request.

`mix hex.audit` does not read Shoddy, because Shoddy comes from GitHub and not from Hex.
Shoddy has no dependency at run time, and the lockfile gives the commit of its `main`
branch. Read the new commits of Shoddy before you run `mix deps.update shoddy`.

Hex can publish an advisory after a merge. Therefore `.github/workflows/audit.yml` also
runs `mix hex.audit` on `main` each day, at 08:07 UTC. GitHub sends an email for a failed
scheduled run to the person who last changed the schedule. The workflow reads the versions
of Erlang and Elixir from `.tool-versions`, so it adds no place for a version.

Until September 2026, the project used `mix deps.audit` from the package `mix_audit`. Its
advisory source did not contain each advisory. Two times in that month, `mix deps.get`
reported advisories for mint, and `mix deps.audit` gave "No vulnerabilities found" for the
same lockfile. `mix hex.audit` reported the second group, so the project removed
`mix_audit`.

For an advisory, do these steps:

1. Read the advisory, and find the fixed version on its page.
2. Update the dependency with `mix deps.update <name>`, and run the checks.
3. If no fixed version exists, or the advisory does not apply, add its ID to
   `hex: [ignore_advisories: [...]]` in `project/0` of `mix.exs`. Give the reason in a
   comment. `mix help hex.audit` gives the form.

The job `lint` and the daily workflow use `mix deps.get --check-locked`. It fails when
`mix.lock` does not agree with `mix.exs`. Run `mix deps.get` on your machine, and commit
the new lockfile.

## Dependency updates

`.github/dependabot.yml` tells Dependabot to open pull requests each week for three kinds
of dependency:

- The GitHub Actions of `.github/workflows/` and `.github/actions/`. One pull request
  holds each new version.
- The packages of `package.json`. One pull request holds the minor and the patch versions,
  and each major version gets its own pull request.
- The packages of `mix.exs` and `mix.lock`, with the same groups as npm.

Each commit message obeys Conventional Commits. The prefix is `ci:` for an action, and
`build(deps):` or `build(deps-dev):` for a package.

Dependabot does not open a major version of `@types/node`. That version follows the
Node.js of `.tool-versions`, and a change of the toolchain changes its four places
together. Dependabot does not change the toolchain.

Dependabot does not open a minor or a major version of Zigler. Each minor version of
Zigler needs a new Zig, and Burrito needs exactly the Zig of `.tool-versions`: Burrito
1.6.0 needs Zig 0.16.0, and Zigler 0.17 needs Zig 0.17.0. When a version of Burrito takes
the new Zig, remove the rule, and change the toolchain in its four places together.

The workflow runs each check for a pull request of Dependabot, as for each pull request.
Read the breaking changes of a major version before a merge. A new version of Playwright
also needs a new browser. The workflow installs it. A session with `EXPRESSO_CHROMIUM` uses
the Chromium of the container, and that Chromium can be older than the new version needs.

## The icons

`priv/icons/lucide.json` holds the Lucide icons, from the file `icon-nodes.json` of the npm
package `lucide-static`. `priv/icons/SOURCE` gives the version. Dependabot does not see the
file. To take a later version:

1. Run `npm pack lucide-static` in an empty directory, and unpack the archive.
2. Write `icon-nodes.json` into `priv/icons/lucide.json` with no white space.
3. Copy the `LICENSE` of the package into `priv/icons/LICENSE`.
4. Write the new version into `priv/icons/SOURCE` and `docs/reference/icon-element.md`.

`Expresso.Icon` reads the file at compile time, so `mix compile` takes the new icons.
