defmodule Expresso.BurritoEntryPoint do
  @moduledoc """
  The entry point of the binary that Burrito makes

  It reads the arguments of the command line and calls `Expresso.main/2`. It does
  this operation in a Burrito binary only.
  """

  use Application

  def start(_, _) do
    if Burrito.Util.running_standalone?() do
      run_cli()
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end

  defp run_cli do
    args = Burrito.Util.Args.get_arguments()

    input_path = Enum.at(args, 0)
    output_path = Enum.at(args, 1)

    Task.start(fn ->
      Expresso.main(input_path, output_path)
      System.stop(0)
    end)
  end
end
