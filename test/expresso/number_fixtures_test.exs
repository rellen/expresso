defmodule Expresso.NumberFixturesTest do
  use ExUnit.Case, async: true

  alias Expresso.Test.NumberFixtures

  # `Expresso.Test.NumberFixtures` tells what the file holds and why Git holds
  # it.
  test "the fixture of the number formats agrees with the chart and the stat" do
    text = NumberFixtures.json()

    if System.get_env("EXPRESSO_FIXTURES") == "write" do
      File.write!(NumberFixtures.path(), text)
    end

    assert File.read!(NumberFixtures.path()) == text, """
    The fixture file #{NumberFixtures.path()} is not current. Write it again:

        EXPRESSO_FIXTURES=write mix test test/expresso/number_fixtures_test.exs
    """
  end
end
