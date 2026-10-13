defmodule Expresso.CheckToolsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Expresso.Check.Tools

  doctest Tools

  @moduletag :tmp_dir

  test "the versions of the packages agree with package.json" do
    versions = "package.json" |> File.read!() |> JSON.decode!() |> Map.fetch!("devDependencies")

    assert Tools.packages() == [
             "playwright@#{versions["playwright"]}",
             "axe-core@#{versions["axe-core"]}"
           ]
  end

  test "the directory is EXPRESSO_TOOLS, or a directory of the cache of the user", %{
    tmp_dir: dir
  } do
    assert Tools.directory(%{"EXPRESSO_TOOLS" => dir}) == dir
    assert Tools.directory(%{}) == :filename.basedir(:user_cache, "expresso")
  end

  test "installs the packages, then the browser, into the directory", %{tmp_dir: dir} do
    run = fn command, args ->
      send(self(), {:run, Path.basename(command), args})
      0
    end

    output = capture_io(fn -> assert Tools.install(%{"EXPRESSO_TOOLS" => dir}, run) == :ok end)

    assert_received {:run, "npm", ["install", "--prefix", ^dir | packages]}
    assert Enum.take(packages, -2) == Tools.packages()

    cli = Path.join(dir, "node_modules/playwright/cli.js")
    assert_received {:run, "node", [^cli, "install", "chromium"]}
    assert output =~ "The tools of --check are in #{dir}."
  end

  test "stops at a command that fails, and gives its exit status", %{tmp_dir: dir} do
    run = fn command, _args ->
      send(self(), {:run, Path.basename(command)})
      if Path.basename(command) == "npm", do: 1, else: 0
    end

    capture_io(fn ->
      assert Tools.install(%{"EXPRESSO_TOOLS" => dir}, run) ==
               {:error, "npm stopped with the exit status 1."}
    end)

    assert_received {:run, "npm"}
    refute_received {:run, "node"}
  end
end
