defmodule Expresso.Presenter.FixturesTest do
  use ExUnit.Case, async: true

  alias Expresso.Test.PresenterFixtures

  # `Expresso.Test.PresenterFixtures` tells what the file holds and why Git
  # holds it.
  test "the fixture file of the TypeScript tests agrees with the definition of the presenter" do
    text = PresenterFixtures.json()

    if System.get_env("EXPRESSO_FIXTURES") == "write" do
      File.write!(PresenterFixtures.path(), text)
    end

    assert File.read!(PresenterFixtures.path()) == text, """
    The fixture file #{PresenterFixtures.path()} is not current. Write it again:

        EXPRESSO_FIXTURES=write mix test test/expresso/presenter/fixtures_test.exs
    """
  end
end
