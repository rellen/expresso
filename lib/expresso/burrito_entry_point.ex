defmodule Expresso.BurritoEntryPoint do
  @moduledoc """
  The entry point of the binary that Burrito makes

  It reads the arguments of the command line and calls `Expresso.main/2`. It does
  this operation in a Burrito binary only.

  The launcher of Burrito starts the VM with `-s elixir start_cli`. After the boot,
  the CLI of Elixir runs the first argument as a script, and then it halts the VM.
  Therefore `start/2` runs the command before it returns, and it halts the VM with
  the exit status of `run/2`. The CLI of Elixir then does not start.
  """

  use Application

  alias Expresso.CommandLine

  @doc """
  Start the application, and run the command line in a Burrito binary

  In a Burrito binary, the function does not return. It halts the VM with the
  exit status of `run/2`.
  """
  @impl Application
  @spec start(Application.start_type(), term()) :: {:ok, pid()} | {:error, term()}
  def start(_, _) do
    if Burrito.Util.running_standalone?() do
      # Without the handler, only a closed standard output waits for ever, so a
      # failure to install it does not stop the command.
      _ = Expresso.SignalHandler.install()
      Burrito.Util.Args.get_arguments() |> run(program()) |> System.halt()
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end

  # The file name of the binary. The launcher of Burrito gives the path of the
  # binary, so the usage text names the file that the person ran.
  defp program do
    case Burrito.Util.Args.get_bin_path() do
      :not_in_burrito -> "expresso"
      path -> Path.basename(path)
    end
  end

  @doc """
  Run the command line of the binary, and give its exit status

  The first argument is the input path, and the second argument is the output
  path. With no argument, the function writes the usage text with the name
  `program` to the standard error, and the exit status is 1. With `--help` or
  `-h` in any position, the function writes the help text with the name
  `program` to the standard output, and the exit status is 0. It then does not
  read the other arguments. `--version` in any position writes the version of
  Expresso in the same way. For a different argument that starts with `-`, and
  for a third path, the function writes the message and the usage text to the
  standard error, and the exit status is 1. `Expresso.CommandLine.parse/1` reads
  the arguments.

  The exit status is 0 when `Expresso.main/2` returns `:ok`, and 1 when it
  returns an error tuple. `Expresso.main/2` writes the message of an error tuple
  to the standard error. For an exception, an exit or a throw, the function
  writes the message to the standard error, and the exit status is 1.

  When the standard output closes before all the HTML is written, as for
  `| head`, the function writes no message, and the exit status is 0. In the
  binary, the launcher of Burrito stops the VM first: `Expresso.SignalHandler`
  tells how.
  """
  @spec run([String.t()], String.t()) :: 0 | 1
  def run(args, program \\ "expresso")

  def run([], program) do
    IO.puts(:stderr, CommandLine.usage(program))
    1
  end

  def run(args, program) do
    case CommandLine.parse(args) do
      :help ->
        IO.write(help(program))
        0

      :version ->
        IO.puts(CommandLine.version())
        0

      {:error, message} ->
        IO.puts(:stderr, [message, ?\n, CommandLine.usage(program)])
        1

      {:paths, input_path, output_path} ->
        render(input_path, output_path)
    end
  end

  defp render(input_path, output_path) do
    case Expresso.main(input_path, output_path) do
      :ok -> 0
      {:error, :closed} -> 0
      {:error, _message} -> 1
    end
  catch
    kind, reason ->
      IO.puts(:stderr, Exception.format(kind, reason, __STACKTRACE__))
      1
  end

  defp help(program) do
    """
    #{CommandLine.usage(program)}

    Make one HTML document from a deck.

    Arguments:
      <input>     The Elixir script of the deck.
      [output]    The file for the HTML. Without it, the HTML goes to the
                  standard output.

    Options:
      -h, --help     Show this help.
          --version  Show the version of Expresso.

    The exit status is 0 when the command writes the HTML, and 1 for an error.
    """
  end
end
