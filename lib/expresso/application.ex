defmodule Expresso.Application do
  use Application

  def start(_, _) do
    args = Burrito.Util.Args.get_arguments()

    maybe_file = args |> Enum.at(0)

    {deck, _} =
      case File.stat(maybe_file) do
        {:ok, _stat} ->
          Code.eval_file(maybe_file)

        _ ->
          IO.puts("Couldn't find file")
          System.halt(1)
      end

    rendered = Expresso.Deck.render(deck)

    case Enum.at(args, 1) do
      nil -> IO.puts(rendered)
      file -> File.write(file, rendered)
    end

    System.halt(0)
  end
end
