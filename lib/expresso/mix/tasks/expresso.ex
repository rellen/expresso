defmodule Mix.Tasks.Expresso do
  @moduledoc """
  A mix task to run expresso from the mix project
  """

  use Mix.Task

  @doc false
  @impl Mix.Task
  def run(args) do
    input_path = Enum.at(args, 0)
    output_path = Enum.at(args, 1)

    Expresso.main(input_path, output_path)
  end
end
