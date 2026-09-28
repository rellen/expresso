defmodule Expresso.EntryPointsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  # A script that returns an `Expresso.Deck` struct. It needs no module, so two
  # runs of the same test give no warning for a module that Elixir redefines.
  @script """
  Expresso.Deck.new("a deck from a script")
  |> Expresso.Deck.add_slide("first", %{heading: "Hello"}, [
    Expresso.Element.TextBox.new("some text")
  ])
  """

  # The standard output and the standard error of a function.
  defp with_output(fun), do: with_io(:stderr, fn -> capture_io(fun) end)

  # Run a function with a standard output that is closed, as for `| head`. The
  # group leader of the process is a device that stopped, so a write to the
  # standard output raises `:terminated`, as it does in `mix expresso`.
  defp with_closed_stdout(fun) do
    {:ok, device} = StringIO.open("")
    ref = Process.monitor(device)
    {:ok, _contents} = StringIO.close(device)

    receive do
      {:DOWN, ^ref, :process, ^device, _reason} -> :ok
    end

    fn ->
      Process.group_leader(self(), device)
      fun.()
    end
    |> Task.async()
    |> Task.await()
  end

  defp write_script(dir, name \\ "deck.exs", source \\ @script) do
    path = Path.join(dir, name)
    File.write!(path, source)
    path
  end

  describe "Expresso.main/2" do
    @tag :tmp_dir
    test "writes the HTML to the output path", %{tmp_dir: dir} do
      input = write_script(dir)
      output = Path.join(dir, "deck.html")

      assert Expresso.main(input, output) == :ok

      html = File.read!(output)

      assert String.starts_with?(html, "<!DOCTYPE html>\n")
      assert html =~ "a deck from a script"
      assert html =~ "some text"
    end

    @tag :tmp_dir
    test "writes the HTML to the standard output without an output path", %{tmp_dir: dir} do
      input = write_script(dir)

      output = capture_io(fn -> assert Expresso.main(input) == :ok end)

      assert output =~ "<!DOCTYPE html>"
      assert output =~ "some text"
    end

    test "writes the usage text to the standard error without an input path" do
      {output, error} = with_output(fn -> assert {:error, _message} = Expresso.main(nil) end)

      assert output == ""
      assert error =~ "Usage: mix expresso <input> [output]"
    end

    test "writes a message to the standard error for an input path that is not present" do
      {output, error} =
        with_output(fn -> assert {:error, _} = Expresso.main("no/such/deck.exs") end)

      assert output == ""
      assert error =~ "Couldn't find input file"
    end

    @tag :tmp_dir
    test "gives {:error, :closed} and no message for a closed standard output",
         %{tmp_dir: dir} do
      input = write_script(dir)

      error =
        capture_io(:stderr, fn ->
          assert with_closed_stdout(fn -> Expresso.main(input) end) == {:error, :closed}
        end)

      assert error == ""
    end

    @tag :tmp_dir
    test "writes a message to the standard error for a script of a different value",
         %{tmp_dir: dir} do
      input = write_script(dir, "number.exs", "42\n")

      {output, error} = with_output(fn -> assert {:error, _} = Expresso.main(input) end)

      assert output == ""
      assert error =~ "must return an Expresso.Deck struct"
    end

    @tag :tmp_dir
    test "gives an error for an output path that it cannot write", %{tmp_dir: dir} do
      input = write_script(dir)
      output = Path.join([dir, "no", "such", "deck.html"])

      error =
        capture_io(:stderr, fn ->
          assert Expresso.main(input, output) ==
                   {:error, "Couldn't write output file: no such file or directory"}
        end)

      assert error =~ "Couldn't write output file: no such file or directory"
    end

    @tag :tmp_dir
    test "accepts a script that declares a module with the DSL", %{tmp_dir: dir} do
      source = """
      defmodule Expresso.EntryPointsTest.ScriptDeck do
        use Expresso

        name "a deck from a module"

        slide do
          text_box do
            text_area do
              text "from the DSL"
            end
          end
        end
      end
      """

      input = write_script(dir, "module_deck.exs", source)

      output = capture_io(fn -> assert Expresso.main(input) == :ok end)

      assert output =~ "a deck from a module"
      assert output =~ "from the DSL"
    end
  end

  describe "Mix.Tasks.Expresso.run/1" do
    @tag :tmp_dir
    test "reads the two paths of the arguments", %{tmp_dir: dir} do
      input = write_script(dir)
      output = Path.join(dir, "deck.html")

      capture_io(fn -> Mix.Tasks.Expresso.run([input, output]) end)

      assert File.read!(output) =~ "a deck from a script"
    end

    @tag :tmp_dir
    test "writes to the standard output with one argument", %{tmp_dir: dir} do
      input = write_script(dir)

      assert capture_io(fn -> Mix.Tasks.Expresso.run([input]) end) =~ "<!DOCTYPE html>"
    end

    test "exits with the status 1, and writes the usage text to the standard error" do
      error =
        capture_io(:stderr, fn ->
          assert catch_exit(Mix.Tasks.Expresso.run([])) == {:shutdown, 1}
        end)

      assert error =~ "Usage: mix expresso"
    end

    test "exits with the status 1 for an input path that is not present" do
      error =
        capture_io(:stderr, fn ->
          assert catch_exit(Mix.Tasks.Expresso.run(["no/such/deck.exs"])) == {:shutdown, 1}
        end)

      assert error =~ "Couldn't find input file"
    end

    test "exits with the status 1, and writes the message and the usage text, for a third path" do
      {output, error} =
        with_output(fn ->
          assert catch_exit(Mix.Tasks.Expresso.run(["a.exs", "b.html", "c.html"])) ==
                   {:shutdown, 1}
        end)

      assert output == ""
      assert error == "Unexpected argument: c.html\nUsage: mix expresso <input> [output]\n"
    end

    test "exits with the status 1, and writes the message and the usage text, for an unknown option" do
      {output, error} =
        with_output(fn ->
          assert catch_exit(Mix.Tasks.Expresso.run(["deck.exs", "--verbose"])) == {:shutdown, 1}
        end)

      assert output == ""
      assert error == "Unknown option: --verbose\nUsage: mix expresso <input> [output]\n"
    end

    test "writes the help of the task for --help and -h" do
      for flag <- ["--help", "-h"] do
        output = capture_io(fn -> Mix.Tasks.Expresso.run(["no/such/deck.exs", flag]) end)

        assert output =~ "mix expresso <input> [output]"
        assert output =~ "`-h`, `--help` - show this help"
        refute output =~ "Couldn't find input file"
      end
    end

    test "writes the version for --version" do
      output = capture_io(fn -> assert Mix.Tasks.Expresso.run(["--version"]) == :ok end)

      assert output == "Expresso #{Mix.Project.config()[:version]}\n"
    end

    test "has a short description, so mix help lists the task" do
      assert Mix.Task.shortdoc(Mix.Tasks.Expresso) == "Make one HTML document from a deck"
    end

    @tag :tmp_dir
    test "stops with no message and no exit for a closed standard output", %{tmp_dir: dir} do
      input = write_script(dir)

      error =
        capture_io(:stderr, fn ->
          assert with_closed_stdout(fn -> Mix.Tasks.Expresso.run([input]) end) == :ok
        end)

      assert error == ""
    end
  end

  describe "Expresso.BurritoEntryPoint.run/2" do
    alias Expresso.BurritoEntryPoint

    @tag :tmp_dir
    test "gives the exit status 0 and writes the HTML to the output path", %{tmp_dir: dir} do
      input = write_script(dir)
      output = Path.join(dir, "deck.html")

      assert BurritoEntryPoint.run([input, output]) == 0
      assert File.read!(output) =~ "a deck from a script"
    end

    @tag :tmp_dir
    test "writes the HTML to the standard output with one argument", %{tmp_dir: dir} do
      input = write_script(dir)

      output = capture_io(fn -> assert BurritoEntryPoint.run([input]) == 0 end)

      assert output =~ "<!DOCTYPE html>"
    end

    test "gives the exit status 1 and writes the usage text to the standard error" do
      {output, error} = with_output(fn -> assert BurritoEntryPoint.run([]) == 1 end)

      assert output == ""
      assert error == "Usage: expresso <input> [output]\n"
    end

    test "writes the name of the binary in the usage text" do
      error =
        capture_io(:stderr, fn ->
          assert BurritoEntryPoint.run([], "expresso_cli_app_linux_x86") == 1
        end)

      assert error == "Usage: expresso_cli_app_linux_x86 <input> [output]\n"
    end

    test "gives the exit status 0 and writes the help text for --help" do
      output =
        capture_io(fn ->
          assert BurritoEntryPoint.run(["--help"], "expresso_cli_app_linux_x86") == 0
        end)

      assert String.starts_with?(output, "Usage: expresso_cli_app_linux_x86 <input> [output]\n")
      assert output =~ "Make one HTML document from a deck."
      assert output =~ "-h, --help"
    end

    test "gives the exit status 0 and writes the version for --version" do
      {output, error} =
        with_output(fn -> assert BurritoEntryPoint.run(["deck.exs", "--version"]) == 0 end)

      assert output == "Expresso #{Mix.Project.config()[:version]}\n"
      assert error == ""
    end

    test "gives the exit status 0 and writes the help text for -h" do
      output = capture_io(fn -> assert BurritoEntryPoint.run(["-h"]) == 0 end)

      assert String.starts_with?(output, "Usage: expresso <input> [output]\n")
      assert output =~ "-h, --help"
    end

    test "writes the help text, and reads no path, for --help after a path" do
      output =
        capture_io(fn -> assert BurritoEntryPoint.run(["no/such/deck.exs", "--help"]) == 0 end)

      assert String.starts_with?(output, "Usage: expresso <input> [output]\n")
      refute output =~ "Couldn't find input file"
    end

    test "gives the exit status 1 for an input path that is not present" do
      {output, error} =
        with_output(fn -> assert BurritoEntryPoint.run(["no/such/deck.exs"]) == 1 end)

      assert output == ""
      assert error =~ "Couldn't find input file"
    end

    test "gives the exit status 1, and writes the message and the usage text, for a third path" do
      {output, error} =
        with_output(fn ->
          assert BurritoEntryPoint.run(
                   ["a.exs", "b.html", "c.html"],
                   "expresso_cli_app_linux_x86"
                 ) ==
                   1
        end)

      assert output == ""

      assert error ==
               "Unexpected argument: c.html\nUsage: expresso_cli_app_linux_x86 <input> [output]\n"
    end

    test "gives the exit status 1, and writes the message and the usage text, for an unknown option" do
      {output, error} =
        with_output(fn ->
          assert BurritoEntryPoint.run(["-x", "deck.exs"], "expresso_cli_app_linux_x86") == 1
        end)

      assert output == ""

      assert error ==
               "Unknown option: -x\nUsage: expresso_cli_app_linux_x86 <input> [output]\n"
    end

    @tag :tmp_dir
    test "gives the exit status 1 for a script that returns a different value", %{tmp_dir: dir} do
      input = write_script(dir, "number.exs", "42\n")

      error = capture_io(:stderr, fn -> assert BurritoEntryPoint.run([input]) == 1 end)

      assert error =~ "must return an Expresso.Deck struct"
    end

    @tag :tmp_dir
    test "gives the exit status 1 for an output path that it cannot write", %{tmp_dir: dir} do
      input = write_script(dir)
      output = Path.join([dir, "no", "such", "deck.html"])

      error = capture_io(:stderr, fn -> assert BurritoEntryPoint.run([input, output]) == 1 end)

      assert error =~ "Couldn't write output file"
    end

    @tag :tmp_dir
    test "gives the exit status 1 and writes an exception to the standard error",
         %{tmp_dir: dir} do
      input = write_script(dir, "raise.exs", ~s[raise "the deck is not complete"\n])

      error = capture_io(:stderr, fn -> assert BurritoEntryPoint.run([input]) == 1 end)

      assert error =~ "RuntimeError"
      assert error =~ "the deck is not complete"
    end

    @tag :tmp_dir
    test "gives the exit status 0 and no message for a closed standard output",
         %{tmp_dir: dir} do
      input = write_script(dir)

      error =
        capture_io(:stderr, fn ->
          assert with_closed_stdout(fn -> BurritoEntryPoint.run([input]) end) == 0
        end)

      assert error == ""
    end
  end

  describe "Expresso.closed_stdout_filter/2" do
    test "drops the report of OTP for a closed standard output" do
      event = %{
        level: :error,
        meta: %{mfa: {:user_drv, :server, 3}},
        msg: {~c"Writer crashed (~p)", [:epipe]}
      }

      assert Expresso.closed_stdout_filter(event, []) == :stop
    end

    test "keeps each other report" do
      events = [
        %{meta: %{mfa: {:user_drv, :server, 3}}, msg: {~c"Writer crashed (~p)", [:eio]}},
        %{meta: %{mfa: {:user_drv, :server, 3}}, msg: {~c"Reader crashed (~p)", [:epipe]}},
        %{meta: %{mfa: {:some_module, :run, 1}}, msg: {~c"Writer crashed (~p)", [:epipe]}},
        %{meta: %{}, msg: {:string, "a message"}}
      ]

      for event <- events do
        assert Expresso.closed_stdout_filter(event, []) == :ignore
      end
    end
  end

  describe "Expresso.SignalHandler" do
    # A test cannot send SIGTERM, because the handler halts the VM. The release
    # tests send it through the launcher of Burrito.
    test "gives each other signal to the handler of OTP" do
      assert Expresso.SignalHandler.handle_event(:sighup, :state) == {:ok, :state}
      assert Expresso.SignalHandler.handle_event(:sigusr2, :state) == {:ok, :state}
    end
  end

  describe "Expresso.Example" do
    test "parses and renders" do
      html = Expresso.Example |> Expresso.parse() |> Expresso.Deck.render()

      assert html =~ "my presso"
      assert html =~ "hello, world!!!"
    end
  end
end
