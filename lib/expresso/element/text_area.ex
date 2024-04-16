defmodule Expresso.Element.TextArea do
  @moduledoc """
  An element that can have text
  """

  use Expresso.Element

  defstruct [:text]

  def new(text) do
    %__MODULE__{text: text}
  end

  def get_assigns(text_box) do
    %__MODULE__{text: text} = text_box
    %{text: text}
  end

  def render(assigns) do
    temple do
      div class: "text-area" do
        Phoenix.HTML.raw(@text)
      end
    end
  end
end
