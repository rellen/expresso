defmodule Expresso.Builtins.Templates.Decks.Default do
  @moduledoc """
  The default deck template

  It gives the header and the footer of each slide.
  """

  use Expresso.Template.Deck

  @doc """
  Make the header of a slide, with the name of the deck

  A deck has no name when the DSL gives no `name` option, or when
  `Expresso.Deck.new/3` takes `nil`. The header is then empty.
  """
  @impl Expresso.Template.Deck
  @spec header(map()) :: Phoenix.HTML.safe()
  def header(assigns) do
    temple do
      div do
        if name = @deck.name do
          span class: "header" do
            "Header " <> name
          end
        end
      end
    end
  end

  @doc """
  Make the footer of a slide

  The footer is empty. The deck option `slide_numbers` shows the number of
  each slide, with each deck template.
  """
  @impl Expresso.Template.Deck
  @spec footer(map()) :: Phoenix.HTML.safe()
  def footer(_assigns) do
    temple do
      div do
        span class: "footer" do
        end
      end
    end
  end
end
