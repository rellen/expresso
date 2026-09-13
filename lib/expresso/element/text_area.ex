defmodule Expresso.Element.TextArea do
  @moduledoc """
  An element that can have text
  """

  use Expresso.Element

  @typedoc "The struct of a text area"
  @type t :: %__MODULE__{}

  defstruct [:text, __spark_metadata__: nil]

  @doc """
  Make a text area with text
  """
  @spec new(String.t()) :: t()
  def new(text) do
    %__MODULE__{text: text}
  end

  @doc """
  Make the assigns of the render function from the struct
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(text_box) do
    %__MODULE__{text: text} = text_box
    %{text: text}
  end

  @doc """
  Make the HTML of a text area
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: "text-area" do
        Phoenix.HTML.raw(@text)
      end
    end
  end
end
