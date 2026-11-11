defmodule Mix.Tasks.Expresso.Credence do
  @moduledoc """
  Find the code that Credence can make faster or more idiomatic

      mix expresso.credence [path ...]

  The task reads each Elixir file of `lib/`, `tools/` and `test/`, or each
  file and each directory that a path gives, with
  `Credence.Pattern.analyze/2`. It writes each issue with its file, its line
  and its rule. It fails when it finds an issue. `mix check` and the job
  `lint` of the workflow run it.

  The task uses only the Pattern round of Credence, which parses the source.
  `Credence.analyze/1` also compiles each file to find the warnings of the
  compiler. It then defines each module again, and it runs the code that a
  module runs at the compile time, such as the build of a NIF.

  The task gives `assumptions: :strict`. Each rule then gives the same result
  as the code for each text. A deck can hold any Unicode text, so a rule that
  assumes one code point for each grapheme does not apply.

  Credence is a dependency in dev and in test, so the task is in `tools/`.
  `docs/development/checks.md` gives the details.
  """

  use Mix.Task

  @shortdoc "Find the code that Credence can make faster or more idiomatic"

  # The directories that the task reads when no path is given.
  @paths ["lib", "tools", "test"]

  @doc false
  @impl Mix.Task
  def run(args) do
    # Credence finds its rules in the modules of its application.
    :ok = Application.ensure_loaded(:credence)

    files = args |> paths() |> Enum.flat_map(&files/1) |> Enum.sort()
    issues = Enum.flat_map(files, &issues/1)
    Enum.each(issues, &Mix.shell().info(format(&1)))

    case length(issues) do
      0 ->
        Mix.shell().info("Credence found no issue in #{length(files)} files.")

      count ->
        Mix.raise(
          "Credence found #{count} issues in #{length(files)} files. " <>
            "Change each line above, or see docs/development/checks.md."
        )
    end
  end

  defp paths([]), do: @paths
  defp paths(paths), do: paths

  defp files(path) do
    cond do
      File.dir?(path) -> Path.wildcard(Path.join(path, "**/*.{ex,exs}"))
      File.regular?(path) -> [path]
      true -> Mix.raise("The path #{path} is not a file or a directory.")
    end
  end

  defp issues(file) do
    file
    |> File.read!()
    |> Credence.Pattern.analyze(assumptions: :strict)
    |> Enum.map(&{file, &1})
  end

  # The message of an issue can have several lines. Each line after the first
  # gets an indent, so that the file and the line of each issue start a line.
  defp format({file, issue}) do
    message = String.replace(issue.message, "\n", "\n    ")
    "#{file}:#{issue.meta[:line]}: #{message} (#{issue.rule})"
  end
end
