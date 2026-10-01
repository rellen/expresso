# The configuration of Credo. Credo merges it with its default configuration.
# The only change is `tools/`, which holds the code for dev and test only.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "tools/", "test/", "config/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      }
    }
  ]
}
