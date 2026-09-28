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
end
