defmodule Expresso.Check.Tools do
  @moduledoc """
  Installs the tools of the browser levels of `--check` into a directory of the user

  `mix expresso --install-check-tools` and `expresso --install-check-tools`
  call `install/2`. The function installs the npm packages `playwright` and
  `axe-core` into `directory/1`, and the Chromium and the headless shell of
  Playwright into the cache of Playwright. The check then finds each tool
  there, so a project with no `node_modules` can run each level. The
  installation needs Node and npm on the `PATH`.

  `--check=browser` in a Mix project also needs the Hex package
  `playwright_ex` in the deps of the project. The binary holds it.
  """

  # The versions of the npm packages come from the `devDependencies` of
  # `package.json`, which the tests of Expresso use. Dependabot changes that
  # file, so a new version also goes to `install/2` with no change here. A
  # dependency on Expresso from a path or from git holds the file. A package
  # for Hex must put the file in its `files`.
  @package_json Path.expand("../../../package.json", __DIR__)
  @external_resource @package_json
  @versions @package_json |> File.read!() |> JSON.decode!() |> Map.fetch!("devDependencies")
  @playwright Map.fetch!(@versions, "playwright")
  @axe Map.fetch!(@versions, "axe-core")

  @doc """
  Return the directory of the tools

  The variable `EXPRESSO_TOOLS` in `env` gives the directory. Without it, the
  directory is `expresso` in the cache directory of the user, such as
  `~/.cache/expresso` on Linux and `~/Library/Caches/expresso` on macOS.
  """
  @spec directory(%{String.t() => String.t()}) :: Path.t()
  def directory(env \\ System.get_env()) do
    case env["EXPRESSO_TOOLS"] do
      nil -> :filename.basedir(:user_cache, "expresso")
      path -> Path.expand(path)
    end
  end

  @doc """
  Return the npm packages that `install/2` installs, with their versions

  Each version is the version of the package in `package.json`, so the list
  has the form `["playwright@<version>", "axe-core@<version>"]`.
  """
  @spec packages() :: [String.t()]
  def packages, do: ["playwright@#{@playwright}", "axe-core@#{@axe}"]

  @doc """
  Install the tools, write the progress, and return `:ok` or an error

  The function runs these commands, in sequence:

  1. `npm install --prefix <directory> playwright axe-core`, with the
     versions of `packages/0`.
  2. `node <directory>/node_modules/playwright/cli.js install chromium`,
     which installs the Chromium and the headless shell of Playwright.

  `run` runs one command with its arguments, and returns its exit status.
  The default writes the output of the command to the standard output.
  """
  @spec install(%{String.t() => String.t()}, (String.t(), [String.t()] -> non_neg_integer())) ::
          :ok | {:error, String.t()}
  def install(env \\ System.get_env(), run \\ &run/2) do
    directory = directory(env)

    with {:ok, npm} <- executable("npm"),
         {:ok, node} <- executable("node"),
         :ok <- make(directory),
         :ok <-
           step(
             run,
             npm,
             ["install", "--prefix", directory, "--no-audit", "--no-fund"] ++ packages()
           ),
         :ok <-
           step(run, node, [
             Path.join(directory, "node_modules/playwright/cli.js"),
             "install",
             "chromium"
           ]) do
      IO.puts("The tools of --check are in #{directory}.")
      :ok
    end
  end

  defp executable(name) do
    case System.find_executable(name) do
      nil ->
        {:error,
         "--install-check-tools needs Node and npm. Install Node, and put `node` and `npm` " <>
           "on the PATH. docs/how-to/check-a-deck.md tells how."}

      path ->
        {:ok, path}
    end
  end

  # The user gives the directory in EXPRESSO_TOOLS, or the directory is in the
  # cache of the user.
  # sobelow_skip ["Traversal.FileModule"]
  defp make(directory) do
    case File.mkdir_p(directory) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "Couldn't make the directory #{directory}: #{:file.format_error(reason)}"}
    end
  end

  defp step(run, command, args) do
    IO.puts("$ #{Enum.join([Path.basename(command) | args], " ")}")

    case run.(command, args) do
      0 -> :ok
      status -> {:error, "#{Path.basename(command)} stopped with the exit status #{status}."}
    end
  end

  # The command is `npm` or `node` from the `PATH`, and the arguments come
  # from this module and from EXPRESSO_TOOLS. System.cmd/3 starts no shell.
  # sobelow_skip ["CI.System"]
  defp run(command, args) do
    {_output, status} = System.cmd(command, args, into: IO.stream(), stderr_to_stdout: true)
    status
  end
end
