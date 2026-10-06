defmodule Counter do
  @moduledoc "A process that counts."

  use GenServer

  def start_link(start), do: GenServer.start_link(__MODULE__, start)

  @impl GenServer
  def init(start), do: {:ok, start}

  @impl GenServer
  def handle_call(:next, _from, count) do
    next = count + 1
    {:reply, next, next}
  end
end
