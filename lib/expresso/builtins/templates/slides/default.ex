defmodule Expresso.Builtins.Templates.Slides.Default do
  use Expresso.Template

  def render(assigns) do
    temple do
      div class: "slide-body" do
        div class: "slide-heading-container" do
          h1 style: "margin: 0.5rem 0; text-align: center" do
            @metadata.heading
          end
        end

        div class: "slide-main" do
          c(&Expresso.Template.render_elements(&1), elements: @elements)
        end
      end
    end
  end
end
