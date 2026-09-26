defmodule Expresso.BurritoEntryPoint do
  @moduledoc """
  The entry point of the binary that Burrito makes

  It reads the arguments of the command line and calls `Expresso.main/2`. It does
  this operation in a Burrito binary only.

  The launcher of Burrito starts the VM with `-s elixir start_cli`. After the boot,
  the CLI of Elixir runs the first argument as a script, and then it halts the VM.
  Therefore `start/2` runs the command before it returns, and it halts the VM with
  the exit status of `run/1`. The CLI of Elixir then does not start.
  """

  use Application

  @doc """
  Start the application, and run the command line in a Burrito binary

  In a Burrito binary, the function does not return. It halts the VM with the
  exit status of `run/1`.
  """
  @impl Application
  @spec start(Application.start_type(), term()) :: {:ok, pid()} | {:error, term()}
  def start(_, _) do
    if Burrito.Util.running_standalone?() do
      Burrito.Util.Args.get_arguments() |> run() |> System.halt()
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end

  @doc """
  Run the command line of the binary, and give its exit status

  The first argument is the input path, and the second argument is the output
  path. The exit status is 0 when `Expresso.main/2` returns `:ok`, and 1 when it
  returns an error tuple. For an exception, an exit or a throw, the function
  writes the message to the standard error, and the exit status is 1.
  """
  @spec run([String.t()]) :: 0 | 1
  def run(args) do
    case Expresso.main(Enum.at(args, 0), Enum.at(args, 1)) do
      :ok -> 0
      {:error, _message} -> 1
    end
  catch
    kind, reason ->
      IO.puts(:stderr, Exception.format(kind, reason, __STACKTRACE__))
      1
  end
end
