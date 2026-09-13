defmodule Expresso.Builtins.Templates.Slides.Default do
  @moduledoc """
  The default slide template

  It gives the heading of a slide and the elements of a slide.
  """

  use Expresso.Template

  @doc """
  Make the body of a slide, with the heading and the elements
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: "slide-body" do
        if heading = Map.get(@metadata, :heading) do
          div class: "slide-heading-container" do
            h1 style: "margin: 0.5rem 0; text-align: center" do
              heading
            end
          end
        end

        div class: "slide-main" do
          c(&Expresso.Template.render_elements(&1), elements: @elements)
        end
      end
    end
  end
end
