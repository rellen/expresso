defmodule Expresso.Element.DiagramMermaidFixturesTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.Diagram.Pele

  # Each `.mmd` file of `test/fixtures/mermaid/` has a `.json` file with the
  # output of the script of Pele, so the other tests of a Mermaid diagram run
  # without Node. This test runs Pele, and it fails when a fixture does not
  # agree with Pele, such as after a new version of Pele. This command writes
  # the fixtures again:
  #
  #     EXPRESSO_MERMAID=write mix test --only mermaid test/expresso/diagram_mermaid_fixtures_test.exs
  @moduletag :mermaid

  for source <- Path.wildcard("test/fixtures/mermaid/*.mmd") do
    @source source
    test "the fixture of #{Path.basename(source)} agrees with Pele" do
      fixture = Path.rootname(@source) <> ".json"
      json = Pele.json!(File.read!(@source), @source)

      if System.get_env("EXPRESSO_MERMAID") == "write", do: File.write!(fixture, json)

      assert File.read!(fixture) == json, """
      #{fixture} does not agree with Pele. Write the fixtures again:

          EXPRESSO_MERMAID=write mix test --only mermaid test/expresso/diagram_mermaid_fixtures_test.exs
      """
    end
  end
end
