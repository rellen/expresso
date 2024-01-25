defmodule Expresso.BurritoEntryPoint do
  use Application

  def start(_, _) do
    args = Burrito.Util.Args.get_arguments()

    input_path = Enum.at(args, 0)
    output_path = Enum.at(args, 1)

    Expresso.main(input_path, output_path)

    System.halt(0)
  end
end
