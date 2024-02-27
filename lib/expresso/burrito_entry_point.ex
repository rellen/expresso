defmodule Expresso.BurritoEntryPoint do
  use Application

  def start(_, _) do
    args = Burrito.Util.Args.get_arguments()

    input_path = Enum.at(args, 0)
    output_path = Enum.at(args, 1)

    Task.start(fn ->
      Expresso.main(input_path, output_path)
      System.stop(0)
    end)

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
