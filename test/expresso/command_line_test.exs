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
end
