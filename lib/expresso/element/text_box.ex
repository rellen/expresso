defmodule Expresso.Element.TextBox do
  @moduledoc """
  An element that can have text or other text-like elements in it
  """

  use Expresso.Element

  @typedoc "The struct of a text box"
  @type t :: %__MODULE__{}

  defstruct [:elements, :at, :steps, on: [], __spark_metadata__: nil]

  @doc """
  Make a text box with text
  """
  @spec new(String.t()) :: t()
  def new(text) do
    elements = [Expresso.Element.TextArea.new(text)]
    %__MODULE__{elements: elements}
  end

  @doc """
  Make the assigns of the render function from the struct
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(text_box) do
    %__MODULE__{elements: elements} = text_box
    %{elements: elements}
  end

  @doc """
  Make the HTML of a text box
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: "text-box" do
        c(&Expresso.Template.render_elements(&1), elements: @elements)
      end
    end
  end
end
