defmodule Expresso.Builtins.Templates.Slides.Default do
  use Expresso.Template

  def render(assigns) do
    temple do
      div do
        h1 style: "font-size: 72px" do
          @heading
        end

        p do
          Phoenix.HTML.raw(@text)
        end
      end
    end
  end
end
