defmodule Expresso.CommandLineTest do
  use ExUnit.Case, async: true

  alias Expresso.CommandLine

  doctest Expresso.CommandLine

  describe "parse/1" do
    test "gives the two paths" do
      assert CommandLine.parse(["deck.exs", "deck.html"]) == {:paths, "deck.exs", "deck.html"}
      assert CommandLine.parse(["deck.exs"]) == {:paths, "deck.exs", nil}
      assert CommandLine.parse([]) == {:paths, nil, nil}
    end

    test "gives :help for --help or -h in any position" do
      for args <- [["--help"], ["-h"], ["deck.exs", "--help"], ["deck.exs", "deck.html", "-h"]] do
        assert CommandLine.parse(args) == :help
      end
    end

    test "gives :help before --version and before an unknown option" do
      assert CommandLine.parse(["--version", "--help"]) == :help
      assert CommandLine.parse(["--verbose", "-h"]) == :help
    end

    test "gives :install_check_tools for --install-check-tools alone" do
      assert CommandLine.parse(["--install-check-tools"]) == :install_check_tools

      assert CommandLine.parse(["deck.exs", "--install-check-tools"]) ==
               {:error, "--install-check-tools takes no other argument"}
    end

    test "gives :version for --version in any position, before an unknown option" do
      for args <- [["--version"], ["deck.exs", "--version"], ["--verbose", "--version"]] do
        assert CommandLine.parse(args) == :version
      end
    end

    test "gives an error for a different argument that starts with -" do
      assert CommandLine.parse(["--verbose"]) == {:error, "Unknown option: --verbose"}
      assert CommandLine.parse(["deck.exs", "-x"]) == {:error, "Unknown option: -x"}
      assert CommandLine.parse(["deck.exs", "deck.html", "--"]) == {:error, "Unknown option: --"}
    end

    test "gives the first unknown option" do
      assert CommandLine.parse(["-a", "-b"]) == {:error, "Unknown option: -a"}
    end

    test "gives an error for a third path" do
      assert CommandLine.parse(["deck.exs", "deck.html", "notes.html"]) ==
               {:error, "Unexpected argument: notes.html"}

      assert CommandLine.parse(["a.exs", "b.html", "c", "d"]) ==
               {:error, "Unexpected argument: c"}
    end

    test "gives an error for an output path that names the input file in each mode" do
      error = {:error, "The output file is the input file"}

      for args <- [
            ["talk.exs", "talk.exs"],
            ["talk.exs", "./talk.exs"],
            ["talk.exs", Path.expand("talk.exs")],
            ["talk.exs", "talk.exs", "--watch"],
            ["talk.exs", "talk.exs", "--check"],
            ["talk.exs", "talk.exs", "--check=layout"]
          ] do
        assert CommandLine.parse(args) == error
      end

      assert CommandLine.parse(["-", "-"]) == {:paths, "-", "-"}
      assert CommandLine.parse(["talk.exs", "talk.html"]) == {:paths, "talk.exs", "talk.html"}
    end

    test "gives an unknown option before a third path" do
      assert CommandLine.parse(["a.exs", "b.html", "c", "-x"]) ==
               {:error, "Unknown option: -x"}
    end

    test "gives the name and the version of mix.exs for version/0" do
      assert CommandLine.version() == "Expresso #{Mix.Project.config()[:version]}"
    end

    test "reads - alone and a path with a directory in front of - as paths" do
      assert CommandLine.parse(["-"]) == {:paths, "-", nil}
      assert CommandLine.parse(["./-deck.exs"]) == {:paths, "./-deck.exs", nil}
    end
  end

  describe "parse/1 with --watch" do
    test "gives the paths and the port 4100 in any order of the arguments" do
      for args <- [
            ["deck.exs", "--watch"],
            ["--watch", "deck.exs"]
          ] do
        assert CommandLine.parse(args) == {:watch, "deck.exs", nil, 4100}
      end

      assert CommandLine.parse(["--watch", "deck.exs", "deck.html"]) ==
               {:watch, "deck.exs", "deck.html", 4100}
    end

    test "reads the port in two forms" do
      assert CommandLine.parse(["deck.exs", "--watch", "--port", "4200"]) ==
               {:watch, "deck.exs", nil, 4200}

      assert CommandLine.parse(["--port=4200", "deck.exs", "--watch"]) ==
               {:watch, "deck.exs", nil, 4200}
    end

    test "gives an error for a port that is not a number from 1 to 65535" do
      for value <- ["0", "65536", "-1", "http", "4200x", ""] do
        assert CommandLine.parse(["deck.exs", "--watch", "--port=" <> value]) ==
                 {:error, "Invalid port: #{value}"}
      end

      assert CommandLine.parse(["deck.exs", "--watch", "--port", "deck.html"]) ==
               {:error, "Invalid port: deck.html"}
    end

    test "gives an error for --port with no value" do
      assert CommandLine.parse(["deck.exs", "--watch", "--port"]) ==
               {:error, "--port needs a number"}
    end

    test "gives an error for --port without --watch" do
      assert CommandLine.parse(["deck.exs", "--port", "4200"]) == {:error, "--port needs --watch"}
    end

    test "gives an error without an input file, and for the standard input or output" do
      assert CommandLine.parse(["--watch"]) == {:error, "--watch needs an input file"}
      assert CommandLine.parse(["-", "--watch"]) == {:error, "--watch needs an input file"}

      assert CommandLine.parse(["deck.exs", "-", "--watch"]) ==
               {:error, "--watch cannot write to the standard output"}
    end

    test "gives :help and :version before the watch options" do
      assert CommandLine.parse(["--watch", "--port", "x", "-h"]) == :help
      assert CommandLine.parse(["--watch", "--version"]) == :version
    end

    test "gives an unknown option and a third path before the watch mode" do
      assert CommandLine.parse(["deck.exs", "--watch", "-x"]) == {:error, "Unknown option: -x"}

      assert CommandLine.parse(["a.exs", "b.html", "c", "--watch"]) ==
               {:error, "Unexpected argument: c"}
    end
  end

  # `OptionParser` reads these four arguments in a different way, so these
  # tests keep the rule of the command: each argument that starts with `-` is
  # an option. See "The two commands" in `docs/architecture.md`.
  describe "parse/1 with --check" do
    test "gives the level, the input and the output in any order of the arguments" do
      assert CommandLine.parse(["deck.exs", "--check"]) == {:check, :basic, "deck.exs", nil, []}
      assert CommandLine.parse(["--check", "deck.exs"]) == {:check, :basic, "deck.exs", nil, []}

      assert CommandLine.parse(["deck.exs", "deck.html", "--check=layout"]) ==
               {:check, :layout, "deck.exs", "deck.html", []}

      assert CommandLine.parse(["--check=a11y", "-"]) == {:check, :a11y, "-", nil, []}
    end

    test "reads each --size in two forms, in sequence" do
      assert CommandLine.parse([
               "deck.exs",
               "--check=a11y",
               "--size",
               "1280x720",
               "--size=1024×768"
             ]) == {:check, :a11y, "deck.exs", nil, [{1280, 720}, {1024, 768}]}
    end

    test "gives an error for a bad size, and for --size without a browser level" do
      for value <- ["1280", "x720", "1280x", "100x100", "1280x720x2", "axb"] do
        assert {:error, "Invalid size: " <> _} =
                 CommandLine.parse(["deck.exs", "--check=layout", "--size", value])
      end

      assert {:error, "--size needs a width" <> _} =
               CommandLine.parse(["deck.exs", "--check=layout", "--size"])

      for args <- [["deck.exs", "--size", "1280x720"], ["deck.exs", "--check", "--size=1280x720"]] do
        assert CommandLine.parse(args) ==
                 {:error, "--size needs --check=layout, --check=a11y or --check=browser"}
      end
    end

    test "gives an error for an unknown level" do
      assert CommandLine.parse(["deck.exs", "--check=all"]) ==
               {:error, "Unknown level of --check: all. Give layout, a11y or browser."}

      assert CommandLine.parse(["deck.exs", "--check="]) ==
               {:error, "Unknown level of --check: . Give layout, a11y or browser."}
    end

    test "gives an error without an input, for the standard output, and with --watch" do
      assert CommandLine.parse(["--check"]) == {:error, "--check needs an input"}

      assert {:error, "--check writes its report to the standard output" <> _} =
               CommandLine.parse(["deck.exs", "-", "--check"])

      assert CommandLine.parse(["deck.exs", "--check", "--watch"]) ==
               {:error, "--check and --watch do not go together"}

      assert CommandLine.parse(["deck.exs", "--check", "--port", "4200"]) ==
               {:error, "--port needs --watch"}
    end
  end

  describe "parse/1 with the argument forms of OptionParser" do
    test "gives each form as an unknown option" do
      for arg <- ["-1", "--no-watch", "--watch=true", "--"] do
        assert CommandLine.parse(["deck.exs", arg]) == {:error, "Unknown option: #{arg}"}
      end
    end
  end

  describe "run/3" do
    import ExUnit.CaptureIO

    test "returns the exit status 1 when the watch mode stops for a port in use" do
      {:ok, socket} = :gen_tcp.listen(0, ip: {127, 0, 0, 1})
      {:ok, port} = :inet.port(socket)

      error =
        capture_io(:stderr, fn ->
          assert CommandLine.run(
                   ["deck.exs", "--watch", "--port", Integer.to_string(port)],
                   "expresso",
                   "help"
                 ) == 1
        end)

      assert error =~ "Port #{port} is in use."
      :gen_tcp.close(socket)
    end

    @tag :tmp_dir
    test "does not replace the deck when the output path names the input file", %{tmp_dir: dir} do
      input = Path.join(dir, "talk.exs")
      File.write!(input, "the deck script")

      error = capture_io(:stderr, fn -> assert CommandLine.run([input, input], "x", "h") == 1 end)

      assert error =~ "The output file is the input file"
      assert File.read!(input) == "the deck script"
    end

    test "writes the help text that the entry point gives" do
      assert capture_io(fn -> assert CommandLine.run(["-h"], "expresso", "the help") == 0 end) ==
               "the help"
    end
  end
end
