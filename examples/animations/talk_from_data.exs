defmodule Examples.TalkFromData do
  use Expresso

  @topics [
    {"Why Elixir", ["Concurrency", "Fault tolerance", "Hot code upgrade"]},
    {"Why the BEAM", ["Processes", "Supervisors", "Distribution"]}
  ]

  name "a talk from data"

  for {title, points} <- @topics do
    slide title do
      heading title

      list do
        reveal true
        for point <- points, do: item(point)
      end
    end
  end
end

Examples.TalkFromData
