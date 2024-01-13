defmodule Expresso.Templates.Decks.Default do
  use Expresso.Template.Deck

  def header(assigns) do
    temple do
      div do
        span do
          "Header " <> @deck.name
        end
      end
    end
  end

  def footer(assigns) do
    temple do
      div do
        span do
          "Footer: slide " <> Integer.to_string(@slide.metadata.slide_number)
        end
      end
    end
  end
end
