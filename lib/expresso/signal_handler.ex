defmodule Expresso.SignalHandler do
  @moduledoc """
  Handles the signals of the operating system in the binary

  For a SIGTERM, the default handler of OTP does an orderly stop of the VM.
  That stop waits for each application to stop, and the command of the binary
  runs in `Expresso.BurritoEntryPoint.start/2`, before the application starts.
  The stop then waits forever, and the logger writes to the standard output
  while it waits.

  The launcher of Burrito 1.6 sends SIGTERM when the reader of the standard
  output stops, as `| head` does. The launcher passes the standard output of
  the VM through a pipe, and it stops the read of that pipe first. Thus each
  write to the standard output also waits forever. Without this handler, the
  binary does not stop. See `stdoutCopyThread` in `deps/burrito/src/erlang_launcher.zig`.

  This handler halts the VM at once for a SIGTERM, and it does not write to the
  standard output. The default handler of OTP handles the other signals.

  The launcher does not forward a SIGTERM that the user sends to the binary.
  `Expresso.LauncherWatch` halts the VM when the launcher stops.

  The exit status is 0. The launcher waits for the VM in two threads, and the
  thread that reads the exit status first decides the status of the binary.
  When the thread that sent SIGTERM reads it first, the binary gives 0 for each
  status of the VM. For a different status of the VM, the binary then gives 0
  or that status by chance. With 0, the binary always gives 0 for a closed
  pipe, as `mix expresso` does.
  """

  @behaviour :gen_event

  @doc """
  Replace the default handler of OTP with this handler
  """
  @spec install() :: :ok | {:error, term()}
  def install do
    :gen_event.swap_handler(
      :erl_signal_server,
      {:erl_signal_handler, []},
      {__MODULE__, []}
    )
  end

  @impl :gen_event
  def init(_args), do: {:ok, nil}

  @impl :gen_event
  def handle_event(:sigterm, state) do
    :erlang.halt(0, flush: false)
    {:ok, state}
  end

  def handle_event(signal, state), do: :erl_signal_handler.handle_event(signal, state)

  @impl :gen_event
  def handle_call(_request, state), do: {:ok, :ok, state}
end
