defmodule Expresso.LauncherWatch do
  @moduledoc """
  The watch that halts the VM of the binary when the launcher of Burrito stops

  The binary that Burrito makes is a launcher. The launcher starts the VM as
  its child process, and it waits for the VM. The launcher of Burrito 1.6 does
  not send SIGTERM or SIGINT on to the VM. Thus a SIGTERM to the binary stopped
  only the launcher, and the VM continued with no parent. In the watch mode,
  the VM then kept the port. In `--check`, the VM waited for ever on the closed
  standard output.

  `start/0` reads the process id of the parent of the VM, which is the
  launcher. It opens a port to a shell loop. The loop reads the parent of the
  VM with `ps`, and it exits when the parent is different. The VM halts when
  the port closes.

  The operating system gives a new parent to a process at once when its
  parent stops. A test of the launcher with `kill -0` is not sufficient,
  because `kill -0` succeeds for a zombie process. A launcher that stopped is a
  zombie until its own parent waits for it.

  The shell loop also stops after the VM halts, because `ps` then finds no VM.
  The VM sees the stop of the launcher in less than one second.
  """

  # The time in seconds between two tests of the parent in the shell loop.
  @interval "0.2"

  # The exit status of a process that SIGTERM stops. The launcher is not
  # present to read it, so the status is only for a developer who reads a trace.
  @status 143

  @doc """
  Watch the parent process of the VM, and halt the VM when it stops

  The function returns `{:error, reason}` and starts no watch when it cannot
  read the parent process, and on Windows.
  """
  @spec start() :: {:ok, pid()} | {:error, term()}
  def start do
    with {:unix, _} <- :os.type(),
         {:ok, parent} <- parent(System.pid()) do
      watch(System.pid(), parent, fn -> :erlang.halt(@status, flush: false) end)
    else
      {:win32, _} -> {:error, :windows}
      {:error, _} = error -> error
    end
  end

  @doc """
  Call `on_stop` when the parent of the process `os_pid` is not `parent`

  The parent changes when the process `parent` stops, and also when the process
  `os_pid` stops. The process that the function returns owns the port of the
  shell loop. It calls `on_stop` when the port closes, and then it stops.
  """
  @spec watch(String.t(), String.t(), (-> term())) :: {:ok, pid()} | {:error, term()}
  def watch(os_pid, parent, on_stop)
      when is_binary(os_pid) and is_binary(parent) and is_function(on_stop, 0) do
    with {:ok, shell} <- find("sh"),
         {:ok, ps} <- find("ps") do
      caller = self()
      ref = make_ref()

      pid =
        spawn(fn ->
          port = open(shell, [ps, os_pid, parent])
          send(caller, {ref, :open})
          wait(port, on_stop)
        end)

      receive do
        {^ref, :open} -> {:ok, pid}
      end
    end
  end

  defp find(name) do
    case System.find_executable(name) do
      nil -> {:error, {:not_found, name}}
      path -> {:ok, path}
    end
  end

  defp open(shell, args) do
    # The loop runs until the launcher stops. The launcher reads the standard
    # output of the VM until each writer closes it, so the port gives the
    # standard output of the loop. With `:nouse_stdio`, the loop wrote to the
    # pipe of the launcher, and the launcher waited for ever after the VM
    # halted. The loop also closes its standard error, so the reader of the
    # standard error of the binary does not wait for the loop. The output of
    # `ps` has spaces before the number, so `$p` has no quotes. When the
    # process is not present, `$p` is empty, and the test fails.
    script = """
    exec 2>/dev/null
    while p=$("$1" -o ppid= -p "$2"); [ $p = "$3" ]; do sleep #{@interval}; done
    """

    Port.open({:spawn_executable, shell}, [:exit_status, args: ["-c", script, "sh" | args]])
  end

  defp wait(port, on_stop) do
    receive do
      {^port, {:exit_status, _status}} -> on_stop.()
    end
  end

  @doc """
  Return the process id of the parent of the operating system process `os_pid`

  The function runs `ps`, which Linux and macOS give.
  """
  @spec parent(String.t()) :: {:ok, String.t()} | {:error, term()}
  # The executable is `ps` from the path, and `os_pid` is one argument, so no
  # shell reads the arguments.
  # sobelow_skip ["CI.System"]
  def parent(os_pid) when is_binary(os_pid) do
    with {:ok, ps} <- find("ps") do
      case System.cmd(ps, ["-o", "ppid=", "-p", os_pid], stderr_to_stdout: true) do
        {output, 0} -> parse(String.trim(output))
        {output, _status} -> {:error, {:ps, String.trim(output)}}
      end
    end
  end

  defp parse(text) do
    case Integer.parse(text) do
      {number, ""} when number > 0 -> {:ok, Integer.to_string(number)}
      _ -> {:error, {:ps, text}}
    end
  end
end
