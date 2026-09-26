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
    if !System.find_executable("timeout"), do: raise("the tests need timeout on the path")

    # A binary installs its release in a directory that has the name of the
    # release and of its version. When that directory is present, the binary does
    # not install again, and it runs the release of an earlier build. Therefore
    # each run of these tests gives the binary a new home directory. Linux reads
    # XDG_DATA_HOME, and macOS reads HOME.
    home = Path.join(System.tmp_dir!(), "expresso-binary-#{System.unique_integer([:positive])}")
    File.mkdir_p!(home)
    on_exit(fn -> File.rm_rf!(home) end)

    %{binary: binary, env: [{"HOME", home}, {"XDG_DATA_HOME", home}]}
  end

  defp run(context, args, opts \\ []) do
    System.cmd("timeout", [@timeout, context.binary | args],
      env: context.env,
      stderr_to_stdout: Keyword.get(opts, :stderr_to_stdout, true)
    )
  end

  defp write_script(dir, name, source) do
    path = Path.join(dir, name)
    File.write!(path, source)
    path
  end

  # Makeup gives each code block a random prefix for its group ids. Two renders of
  # the same deck then give different ids, and the other bytes are equal.
  defp normalize(html), do: String.replace(html, ~r/data-group-id="\d+-/, ~s(data-group-id="))

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

  test "writes the same HTML as Expresso.main/2", %{tmp_dir: dir} = context do
    expected = Path.join(dir, "expected.html")
    actual = Path.join(dir, "actual.html")

    assert Expresso.main("examples/dsl_deck.exs", expected) == :ok
    assert {_output, 0} = run(context, ["examples/dsl_deck.exs", actual])

    assert difference(normalize(File.read!(actual)), normalize(File.read!(expected))) == nil
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
    assert output =~ "Usage:"
  end

  test "gives the exit status 1 for an input path that is not present", context do
    assert {output, 1} = run(context, ["no/such/deck.exs"])
    assert output =~ "Couldn't find input file"
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
