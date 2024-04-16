defmodule Expresso.Builtins.Templates.Decks.Default do
  use Expresso.Template.Deck

  def header(assigns) do
    temple do
      div do
        span class: "header" do
          "Header " <> @deck.name
        end
      end
    end
  end

  def footer(assigns) do
    temple do
      div do
        span class: "footer" do
          "Footer: slide " <> Integer.to_string(@slide.metadata.slide_number)
        end
      end
    end
  end
end
