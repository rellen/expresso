defmodule Expresso.Element.TextBox do
  @moduledoc """
  An element that can have text or other text-like elements in it
  """

  use Expresso.Element

  defstruct [:elements]

  def new(text) do
    elements = [Expresso.Element.TextArea.new(text)]
    %__MODULE__{elements: elements}
  end

  def get_assigns(text_box) do
    %__MODULE__{elements: elements} = text_box
    %{elements: elements}
  end

  def render(assigns) do
    temple do
      div class: "text-box" do
        c(&Expresso.Template.render_elements(&1), elements: @elements)
      end
    end
  end
end
