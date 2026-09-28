defmodule Expresso.SignalHandler do
  @moduledoc """
  The handler of the signals of the operating system in the binary

  The default handler of OTP stops the VM in order for a SIGTERM. That stop
  waits for each application to stop, and the command of the binary runs in
  `Expresso.BurritoEntryPoint.start/2`, before the application starts. The
  stop then waits for ever, and the logger writes to the standard output while
  it waits.

  The launcher of Burrito 1.6 sends SIGTERM when the reader of the standard
  output stops, as `| head` does. The launcher passes the standard output of
  the VM through a pipe, and it stops the read of that pipe first. Thus each
  write to the standard output also waits for ever, and the binary did not
  stop. See `stdoutCopyThread` in `deps/burrito/src/erlang_launcher.zig`.

  This handler halts the VM at once for a SIGTERM, and it does not write to the
  standard output. The default handler of OTP handles the other signals.

  The exit status is 0. The launcher waits for the VM in two threads, and the
  thread that reads the exit status first decides the status of the binary.
  When the thread that sent SIGTERM reads it first, the binary gives 0 for each
  status of the VM. A different status of the VM then gives 0 or that status
  by chance. With 0, a closed pipe always gives 0, as `mix expresso` does.
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
