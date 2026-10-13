defmodule Expresso.CheckTest do
  # The tests write the warnings of a theme to the standard error, so they do
  # not run with a test that captures it.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Expresso.Check
  alias Expresso.Check.{Browser, Document}

  doctest Expresso.Check, only: [named: 2, variants: 1]
  doctest Expresso.Check.Document
  doctest Expresso.Check.Browser
  doctest Expresso.Check.Session

  @moduletag :tmp_dir

  # Write a deck script that makes its deck with `Expresso.Builder`.
  defp deck_file(dir, name, source) do
    path = Path.join(dir, name)
    File.write!(path, "alias Expresso.Builder, as: B\n" <> source)
    path
  end

  # Run the check, and return the exit status, the standard output and the
  # standard error.
  defp run(args) do
    error =
      capture_io(:stderr, fn ->
        output =
          capture_io(fn ->
            send(self(), {:status, Check.run(args.input, args[:output], args.level)})
          end)

        send(self(), {:output, output})
      end)

    assert_received {:status, status}
    assert_received {:output, output}
    {status, output, error}
  end

  describe "--check with no tool" do
    test "a good deck gives no problem and the exit status 0", %{tmp_dir: dir} do
      input =
        deck_file(dir, "good.exs", """
        B.deck([B.slide("one", heading: "Hello", elements: [])], name: "Good")
        """)

      {status, output, _error} = run(%{input: input, level: :basic})

      assert status == 0
      assert output =~ "Check of #{input}: 1 slide\n"
      assert output =~ "Checks: the render, the theme and the text for a screen reader"
      assert output =~ ~r/Notes:\n  - The document is \d+ KB\.\n/
      refute output =~ "Slide 1"
      assert String.ends_with?(output, "\nNo problems.\n")
    end

    test "writes the HTML to the output file", %{tmp_dir: dir} do
      input =
        deck_file(dir, "out.exs", """
        B.deck([B.slide("one", heading: "Hello", elements: [])], name: "Out")
        """)

      output = Path.join(dir, "out.html")
      {0, _report, _error} = run(%{input: input, output: output, level: :basic})

      assert "<!DOCTYPE html>" <> _ = File.read!(output)
    end

    test "a theme under a minimum of contrast is a problem, with the exit status 1", %{
      tmp_dir: dir
    } do
      input =
        deck_file(dir, "pale.exs", """
        colors = Map.merge(Expresso.Palette.Builtin.fetch!(:default).colors, %{base03: "#dddddd"})
        B.deck([B.slide("one", heading: "Pale", elements: [])], name: "Pale", theme: [colors: colors])
        """)

      {status, output, _error} = run(%{input: input, level: :basic})

      assert status == 1
      assert output =~ "\nProblems:\n  - Theme: the theme gives "
      assert output =~ "\n  - Theme: the theme gives code_comment a contrast of 1.28:1"
      assert output =~ ~r/\n\d+ problems\.\n\z/
    end

    test "notes an image and a diagram with no alt text, and a slide with no visible heading", %{
      tmp_dir: dir
    } do
      input =
        deck_file(dir, "notes.exs", """
        B.deck(
          [
            B.slide("one", heading: "Pictures", elements: [B.image("#{Path.expand("test/fixtures/dot.png")}")]),
            B.slide(elements: [B.diagram("#{Path.expand("test/fixtures/flow.svg")}")]),
            B.slide(sr_heading: false, elements: [B.text_area(text: "Quiet")])
          ],
          name: "Notes"
        )
        """)

      {status, output, _error} = run(%{input: input, level: :basic})

      assert status == 0

      assert output =~
               "  - Slide 1 “one”: 1 × an image with no alt text, so a screen reader skips it.\n"

      assert output =~
               "  - Slide 2: 1 × a diagram with no alt text, so a screen reader reads the text of its SVG.\n"

      assert output =~ "  - Slide 2: only a hidden heading, so the slide shows no title.\n"
      assert output =~ "  - Slide 3: no h1, so a screen reader finds no name for the slide.\n"
    end

    test "an input that does not render is an error, with the exit status 1", %{tmp_dir: dir} do
      input = deck_file(dir, "bad.exs", ":not_a_deck\n")
      {status, output, error} = run(%{input: input, level: :basic})

      assert status == 1
      assert output == ""
      assert error =~ "must return an Expresso.Deck struct"

      {1, "", missing} = run(%{input: Path.join(dir, "missing.exs"), level: :basic})
      assert missing =~ "Couldn't find input file"
    end
  end

  describe "the tools of the levels" do
    test "a missing browser gives an error that tells how to install one", %{tmp_dir: dir} do
      assert {:error, message} = Browser.find(%{"EXPRESSO_CHROMIUM" => Path.join(dir, "none")})
      assert message =~ "EXPRESSO_CHROMIUM gives"

      assert {:ok, path} = Browser.find(%{"EXPRESSO_CHROMIUM" => deck_file(dir, "chrome", "")})
      assert path == Path.join(dir, "chrome")
    end

    test "finds the headless shell of Playwright before its Chromium", %{tmp_dir: dir} do
      shell = Path.join(dir, "chromium_headless_shell-1194/chrome-linux/headless_shell")
      chromium = Path.join(dir, "chromium-1194/chrome-linux/chrome")

      for path <- [shell, chromium] do
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, "")
      end

      env = %{"PLAYWRIGHT_BROWSERS_PATH" => dir}
      assert Browser.playwright(env) == shell
      assert Browser.find(env) == {:ok, shell}

      File.rm!(shell)
      assert Browser.playwright(env) == chromium
    end

    test "knows a command that installs a snap", %{tmp_dir: dir} do
      snap = deck_file(dir, "snap", "")
      link = Path.join(dir, "chromium")
      File.ln_s!(snap, link)

      script = Path.join(dir, "chromium-browser")
      File.write!(script, "#!/bin/sh\necho 'install the snap'\nexec snap install chromium\n")
      chrome = Path.join(dir, "chrome")
      File.write!(chrome, "#!/bin/sh\nexec /opt/chrome/chrome \"$@\"\n")

      assert Browser.snap?(link)
      assert Browser.snap?(script)
      refute Browser.snap?(chrome)
      refute Browser.snap?(Path.join(dir, "none"))
    end

    test "finds axe-core in node_modules of a directory or a parent", %{tmp_dir: dir} do
      axe = Path.join(dir, "node_modules/axe-core/axe.min.js")
      File.mkdir_p!(Path.dirname(axe))
      File.write!(axe, "")
      deck = Path.join(dir, "talks/one")
      File.mkdir_p!(deck)

      assert Browser.find_axe([deck], %{}) == {:ok, axe}
      assert Browser.find_axe([deck], %{"EXPRESSO_AXE" => axe}) == {:ok, axe}
    end

    test "a missing axe-core gives an error that tells how to install it", %{tmp_dir: dir} do
      assert {:error, message} = Browser.find_axe(["/"], %{})
      assert message =~ "npm install --save-dev axe-core"

      assert {:error, message} = Browser.find_axe([dir], %{"EXPRESSO_AXE" => "/none/axe.js"})
      assert message =~ "EXPRESSO_AXE gives /none/axe.js"
    end

    test "a missing tool stops the check before the render", %{tmp_dir: dir} do
      input = deck_file(dir, "never.exs", "raise \"rendered\"\n")
      previous = System.get_env("EXPRESSO_AXE")
      System.put_env("EXPRESSO_AXE", "/none/axe.js")

      try do
        {status, "", error} = run(%{input: input, level: :a11y})
        assert status == 1
        refute error =~ "rendered"
      after
        if previous,
          do: System.put_env("EXPRESSO_AXE", previous),
          else: System.delete_env("EXPRESSO_AXE")
      end
    end

    test "a browser that does not end in its time is stopped, with an error", %{tmp_dir: dir} do
      browser = Path.join(dir, "slow")
      File.write!(browser, "#!/bin/sh\nsleep 30\n")
      File.chmod!(browser, 0o755)

      {time, result} =
        :timer.tc(fn -> Browser.run("<body></body>", browser, nil, probe_timeout: 300) end)

      assert {:error, message} = result
      assert message =~ "did not end in 0 s"
      assert time < 10_000_000
    end

    test "a browser that fails gives its exit status", %{tmp_dir: dir} do
      browser = Path.join(dir, "failing")
      File.write!(browser, "#!/bin/sh\nexit 3\n")
      File.chmod!(browser, 0o755)

      assert Browser.run("<body></body>", browser) ==
               {:error, "The browser #{browser} stopped with the exit status 3."}
    end

    test "the browser level tells how to install the npm package playwright", %{tmp_dir: dir} do
      assert {:error, message} = Expresso.Check.Session.find(["/"], %{})
      assert message =~ "npm install --save-dev playwright axe-core"

      assert {:error, message} =
               Expresso.Check.Session.find([dir], %{"EXPRESSO_PLAYWRIGHT" => "/none/cli.js"})

      assert message =~ "EXPRESSO_PLAYWRIGHT gives /none/cli.js"
    end

    test "a page with no result is an error" do
      assert {:error, "The page wrote no result." <> _} = Browser.result("<body></body>")
    end

    test "the size note names the largest files" do
      uri = fn type, bytes -> ~s( src="data:#{type};base64,#{String.duplicate("A", bytes)}") end
      html = uri.("image/png", 4096) <> uri.("image/jpeg", 8192) <> uri.("image/gif", 100)

      assert %{notes: [note]} = Document.size(html)
      assert note =~ "The largest files: image/jpeg 6 KB, image/png 3 KB."
    end
  end
end
