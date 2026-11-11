# The configuration of Credo. Credo merges it with its default configuration.
# It adds `tools/`, which holds the code for dev and test only, and the plugin
# ExSlop. The configuration has no list `checks.enabled`, so the plugin turns on
# its recommended checks. See docs/development/checks.md.
%{
  configs: [
    %{
      name: "default",
      plugins: [{ExSlop, []}],
      checks: %{
        extra: [
          # An assert of a test compares a count with `length/1`, because the
          # count is the result that the test expects. A list pattern cannot
          # give a count such as 2000.
          {ExSlop.Check.Refactor.LengthComparison, files: %{excluded: ["test/"]}}
        ]
      },
      files: %{
        included: ["lib/", "tools/", "test/", "config/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      }
    }
  ]
}
