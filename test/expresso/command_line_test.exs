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

    test "gives :help before an unknown option" do
      assert CommandLine.parse(["--version", "--help"]) == :help
    end

    test "gives an error for a different argument that starts with -" do
      assert CommandLine.parse(["--version"]) == {:error, "Unknown option: --version"}
      assert CommandLine.parse(["deck.exs", "-x"]) == {:error, "Unknown option: -x"}
      assert CommandLine.parse(["deck.exs", "deck.html", "--"]) == {:error, "Unknown option: --"}
    end

    test "gives the first unknown option" do
      assert CommandLine.parse(["-a", "-b"]) == {:error, "Unknown option: -a"}
    end

    test "reads - alone and a path with a directory in front of - as paths" do
      assert CommandLine.parse(["-"]) == {:paths, "-", nil}
      assert CommandLine.parse(["./-deck.exs"]) == {:paths, "./-deck.exs", nil}
    end
  end
end
