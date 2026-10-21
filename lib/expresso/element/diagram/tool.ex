defmodule Expresso.Element.Diagram.Tool do
  @moduledoc """
  Finds and runs the tool that draws a graph, such as Graphviz

  Expresso and the binary of Burrito do not hold the tools. The function
  `find/3` looks for the program of a tool on the `PATH`, and a variable of
  the environment, such as `EXPRESSO_DOT`, gives a different path. A tool that
  is not present stops the render with a message that names the tool and the
  way to install it.

  `System.cmd/3` cannot keep the standard error apart from the standard
  output. Therefore the tool writes the SVG to a file in a private directory,
  and the standard error goes into the standard output. A tool that fails
  stops the render with that output, which holds the message of the tool,
  such as a syntax error and its line. A tool that succeeds can also write a
  warning, such as a color that it does not know. The render does not show
  that warning, so a test does not write to the standard error.
  """

  @typedoc "A tool: its name for the user, its program and its variable of the environment"
  @type t :: %{name: String.t(), program: String.t(), variable: String.t(), install: String.t()}

  @doc """
  Find the program of a tool

  The variable of the tool in `env` gives the path of the program. Without
  the variable, the function looks for the program on the `PATH`. `src` is
  the path of the source, for the message.
  """
  @spec find(t(), Path.t(), %{String.t() => String.t()}) ::
          {:ok, Path.t()} | {:error, String.t()}
  def find(tool, src, env \\ System.get_env()) do
    case env[tool.variable] do
      nil -> on_path(tool, src)
      path -> given(tool, path)
    end
  end

  defp on_path(tool, src) do
    case System.find_executable(tool.program) do
      nil ->
        {:error,
         "the diagram \"#{src}\" needs #{tool.name}, and the render does not find " <>
           "`#{tool.program}` on the path. Install #{tool.name} from #{tool.install}, " <>
           "or give its path in #{tool.variable}"}

      path ->
        {:ok, path}
    end
  end

  @doc """
  The identity of the program of a tool, for the key of a cache

  The identity is the path of the program and the time and the size of its
  file, so a new version of the tool gives a new identity. The function
  returns `nil` for a tool that is not present.
  """
  @spec identity(t(), Path.t()) :: {Path.t(), integer(), non_neg_integer()} | nil
  def identity(tool, src) do
    with {:ok, path} <- find(tool, src),
         {:ok, %File.Stat{mtime: mtime, size: size}} <- File.stat(path, time: :posix) do
      {path, mtime, size}
    else
      _other -> nil
    end
  end

  defp given(tool, path) do
    if File.regular?(path),
      do: {:ok, path},
      else: {:error, "#{tool.variable} gives #{path}, and that file does not exist"}
  end

  @doc """
  Run a tool, and return the SVG that it writes

  `command` is a function that takes the private directory of the run and
  returns the arguments of the program and its variables of the environment.
  The tool writes the SVG to `graph.svg` in that directory. `files` go into the
  directory before the run, such as the files of a font. The function raises an
  `ArgumentError` for a tool that is not present and for a tool that fails.
  """
  @spec run!(t(), Path.t(), (Path.t() -> {[String.t()], [{String.t(), String.t()}]}), [
          {String.t(), binary()}
        ]) :: String.t()
  # The program comes from the `PATH` or from the variable of the tool, and
  # System.cmd/3 starts no shell, so no shell reads the arguments. Each file is
  # in a private directory of this run.
  # sobelow_skip ["CI.System", "Traversal"]
  def run!(tool, src, command, files \\ []) do
    program =
      case find(tool, src) do
        {:ok, program} -> program
        {:error, message} -> raise ArgumentError, message
      end

    private_dir = Expresso.PrivateDir.open!("graph")

    try do
      for {name, bytes} <- files, do: File.write!(Path.join(private_dir.path, name), bytes)
      {args, env} = command.(private_dir.path)

      case System.cmd(program, args, stderr_to_stdout: true, env: env) do
        {_output, 0} ->
          File.read!(Path.join(private_dir.path, "graph.svg"))

        {message, status} ->
          raise ArgumentError,
                "#{tool.name} did not draw the diagram \"#{src}\", and it ended with the " <>
                  "status #{status}:\n\n#{String.trim(message)}"
      end
    after
      Expresso.PrivateDir.close(private_dir)
    end
  end
end
