# The configuration of `mix check`. `docs/development.md` gives each tool.

# The target of Burrito for this computer. The tool `release` makes the binary
# for this target only, because a binary of a different target does not run
# here. The tool `release_tests` then runs that binary.
burrito_target =
  case {:os.type(), to_string(:erlang.system_info(:system_architecture))} do
    {{:unix, :darwin}, "aarch64" <> _} -> "macos_arm"
    {{:unix, :darwin}, "x86_64" <> _} -> "macos_x86"
    {{:unix, :linux}, "aarch64" <> _} -> "linux_arm"
    {{:unix, :linux}, "x86_64" <> _} -> "linux_x86"
    {os, architecture} -> raise "Burrito has no target for #{inspect(os)} on #{architecture}"
  end

[
  # In the retry mode, `mix check` runs only the tools that failed in the last
  # run. A tool with a dependency that does not run is then skipped, and a skipped
  # tool does not fail the run. Therefore each run of `mix check` runs each tool.
  retry: false,
  tools: [
    {:compiler, "mix compile --warnings-as-errors"},
    {:sobelow, "mix sobelow --exit --skip"},

    # The security advisories and the retirements of the dependencies on Hex.
    {:hex_audit, "mix hex.audit"},

    # The browser tests. They start after the unit tests, so fewer tools use the
    # processor while a browser test waits for the page.
    {:e2e, "mix test --only e2e", deps: [:ex_unit]},

    # The binary of Burrito and its tests. The release uses the build of prod.
    # The tests start after the browser tests, and only after a release that
    # succeeded. `docs/development.md` gives the details in "The release tests".
    {:release, "mix release expresso_cli_app --overwrite",
     env: %{"MIX_ENV" => "prod", "BURRITO_TARGET" => burrito_target}},
    # The test of Expresso as a dev dependency of a project. It fetches the
    # dependencies of that project, so it needs the network.
    {:dependency, "mix test --only dependency", deps: [:e2e]},
    {:release_tests, "mix test --only release",
     env: %{"EXPRESSO_BINARY" => "burrito_out/expresso_cli_app_" <> burrito_target},
     deps: [{:release, status: :ok}, :e2e]}
  ]
]
