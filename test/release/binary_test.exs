defmodule Expresso.BinaryTest do
  # The tests of the binary that Burrito makes. Each test runs the binary as a
  # person does, from the root of the repository. `mix test --only release` runs
  # them, and `EXPRESSO_BINARY` gives the path of the binary. `mix test` does not
  # run them. `docs/development.md` gives the commands.
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @moduletag :release
  @moduletag :tmp_dir

  # The time in seconds that `timeout` gives a run of the binary. A binary that
  # does not halt then gives the exit status 124, and not a test that stops.
  @timeout "60"

  setup_all do
    binary =
      case System.get_env("EXPRESSO_BINARY") do
        nil -> raise "EXPRESSO_BINARY must give the path of the binary. See docs/development.md."
        path -> Path.expand(path)
      end

    if not File.regular?(binary), do: raise("#{binary} is not a file")

    # GNU coreutils gives `timeout`. Homebrew on macOS gives it as `gtimeout`.
    timeout =
      System.find_executable("timeout") || System.find_executable("gtimeout") ||
        raise "the tests need timeout or gtimeout of GNU coreutils on the path"

    # A binary installs its release in a directory that has the name of the
    # release and of its version. When that directory is present, the binary does
    # not install again, and it runs the release of an earlier build. Therefore
    # each run of these tests gives the binary a new home directory. Linux reads
    # XDG_DATA_HOME, and macOS reads HOME.
    home = Path.join(System.tmp_dir!(), "expresso-binary-#{System.unique_integer([:positive])}")
    File.mkdir_p!(home)
    on_exit(fn -> File.rm_rf!(home) end)

    %{binary: binary, timeout_command: timeout, env: [{"HOME", home}, {"XDG_DATA_HOME", home}]}
  end

  defp run(context, args, opts \\ []) do
    System.cmd(context.timeout_command, [@timeout, context.binary | args],
      env: context.env,
      stderr_to_stdout: Keyword.get(opts, :stderr_to_stdout, true)
    )
  end

  # The standard output of a run, without the standard error. `run/3` cannot
  # discard the standard error, so the shell sends it to /dev/null.
  defp standard_output(context, args) do
    command = [context.timeout_command, @timeout, context.binary | args]
    System.cmd("sh", ["-c", ~s(exec "$@" 2>/dev/null), "sh" | command], env: context.env)
  end

  defp write_script(dir, name, source) do
    path = Path.join(dir, name)
    File.write!(path, source)
    path
  end

  # A part of each document at the first byte that is different, or nil for two
  # equal documents. A failure then shows a short part, and not two documents.
  defp difference(left, right) do
    size = :binary.longest_common_prefix([left, right])

    if size == byte_size(left) and size == byte_size(right) do
      nil
    else
      part = fn html -> binary_part(html, size, min(80, byte_size(html) - size)) end
      {size, part.(left), part.(right)}
    end
  end

  # The deck has a code block, so the group ids of Makeup are a part of the
  # comparison.
  test "writes the same HTML as Expresso.main/2", %{tmp_dir: dir} = context do
    expected = Path.join(dir, "expected.html")
    actual = Path.join(dir, "actual.html")

    assert Expresso.main("examples/dsl_deck.exs", expected) == :ok
    assert {_output, 0} = run(context, ["examples/dsl_deck.exs", actual])

    html = File.read!(actual)
    assert html =~ "data-group-id="
    assert difference(html, File.read!(expected)) == nil
  end

  test "writes the HTML to the standard output with one argument", context do
    expected = capture_io(fn -> assert Expresso.main("examples/demo.exs") == :ok end)

    assert {output, 0} = run(context, ["examples/demo.exs"], stderr_to_stdout: false)
    assert difference(output, expected) == nil
  end

  # The launcher of Burrito starts the CLI of Elixir, and that CLI runs its first
  # argument as a script. The entry point must halt the VM before this occurs.
  test "evaluates the script one time", %{tmp_dir: dir} = context do
    count = Path.join(dir, "count")

    source = """
    File.write!(#{inspect(count)}, "x", [:append])
    Expresso.Deck.new("a counted deck")
    """

    input = write_script(dir, "count.exs", source)

    assert {_output, 0} = run(context, [input, Path.join(dir, "deck.html")])
    assert File.read!(count) == "x"
  end

  # The CLI of Elixir halts the VM after it runs the script. A render that takes
  # more time than the script then gave no file and the exit status 0.
  test "writes all the HTML of a deck that takes a long time to render",
       %{tmp_dir: dir} = context do
    source = """
    Enum.reduce(1..2000, Expresso.Deck.new("a large deck"), fn n, deck ->
      Expresso.Deck.add_slide(deck, "slide_\#{n}", %{heading: "Slide \#{n}"}, [
        Expresso.Element.TextBox.new("text \#{n}")
      ])
    end)
    """

    input = write_script(dir, "large.exs", source)
    output = Path.join(dir, "large.html")

    assert {_output, 0} = run(context, [input, output])

    html = File.read!(output)
    assert html =~ "Slide 2000"
    assert String.ends_with?(html, "</html>")
  end

  test "gives the exit status 1 and writes the usage text with no argument", context do
    assert {output, 1} = run(context, [])
    assert output =~ "Usage: #{Path.basename(context.binary)} <input> [output]\n"
    refute output =~ "mix expresso"

    assert standard_output(context, []) == {"", 1}
  end

  test "gives the exit status 0 and writes the version for --version", context do
    assert standard_output(context, ["--version"]) ==
             {"Expresso #{Mix.Project.config()[:version]}\n", 0}
  end

  test "gives the exit status 0 and writes the help text for --help", context do
    assert {output, 0} = run(context, ["--help"])
    assert output =~ "Usage: #{Path.basename(context.binary)} <input> [output]\n"
    assert output =~ "-h, --help"
  end

  test "gives the exit status 0 and reads no path for -h after a path", context do
    assert {output, 0} = run(context, ["no/such/deck.exs", "-h"])
    assert output =~ "Usage: #{Path.basename(context.binary)} <input> [output]\n"
    refute output =~ "Couldn't find input file"
  end

  test "gives the exit status 1 for an input path that is not present", context do
    assert {output, 1} = run(context, ["no/such/deck.exs"])
    assert output =~ "Couldn't find input file"

    assert standard_output(context, ["no/such/deck.exs"]) == {"", 1}
  end

  # The launcher of Burrito stops the VM with SIGTERM when the reader of the
  # standard output stops. Before `Expresso.SignalHandler`, the binary then
  # waited for ever, and `timeout` gave 124. `true` reads nothing, and the deck
  # is larger than the buffer of a pipe, so a write always fails.
  test "stops at once, with the exit status 0 and no message, for a closed pipe", context do
    command = [context.timeout_command, @timeout, context.binary, "examples/dsl_deck.exs"]
    script = ~s({ "$@"; echo "exit status: $?" >&2; } | true)

    assert System.cmd("sh", ["-c", script, "sh" | command],
             env: context.env,
             stderr_to_stdout: true
           ) == {"exit status: 0\n", 0}
  end

  test "gives the exit status 1 for an unknown option", context do
    assert {output, 1} = run(context, ["--verbose"])
    assert output =~ "Unknown option: --verbose\n"
    assert output =~ "Usage: #{Path.basename(context.binary)} <input> [output]\n"

    assert standard_output(context, ["--verbose"]) == {"", 1}
  end

  test "gives the exit status 1 for an output path that it cannot write",
       %{tmp_dir: dir} = context do
    output_path = Path.join([dir, "no", "such", "deck.html"])

    assert {output, 1} = run(context, ["examples/dsl_deck.exs", output_path])
    assert output =~ "Couldn't write output file: no such file or directory"
  end

  test "gives the exit status 1 for a script that returns a different value",
       %{tmp_dir: dir} = context do
    input = write_script(dir, "number.exs", "42\n")

    assert {output, 1} = run(context, [input])
    assert output =~ "must return an Expresso.Deck struct"
  end

  test "gives the exit status 1 and writes the exception for a script that raises",
       %{tmp_dir: dir} = context do
    input = write_script(dir, "raise.exs", ~s[raise "the deck is not complete"\n])

    assert {output, 1} = run(context, [input])
    assert output =~ "RuntimeError"
    assert output =~ "the deck is not complete"
  end
end
