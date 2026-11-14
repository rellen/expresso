defmodule Expresso.ExportBrowserTest do
  # The test changes `PATH`, so it does not run with other tests.
  use ExUnit.Case, async: false

  describe "the error for no browser" do
    test "names the options of the export and the guide" do
      # No name of a browser is on an empty path, and the directories of
      # Playwright and of macOS do not exist for this home directory.
      path = System.get_env("PATH")
      System.put_env("PATH", "")
      on_exit(fn -> System.put_env("PATH", path) end)

      env = %{"HOME" => "/nonexistent", "PLAYWRIGHT_BROWSERS_PATH" => "/nonexistent"}

      found =
        Expresso.Check.Browser.find(env, "--pdf and --png need", "docs/how-to/export-a-deck.md")

      case found do
        {:error, message} ->
          assert message ==
                   "--pdf and --png need Chrome or Chromium. Install one of them, or give its " <>
                     "path in EXPRESSO_CHROMIUM. docs/how-to/export-a-deck.md tells how."

        # A computer with Chrome in a usual place of macOS finds it.
        {:ok, browser} ->
          assert browser =~ "/Applications/"
      end
    end
  end
end
