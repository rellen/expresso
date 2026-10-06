defmodule Examples.SectionHeader do
  use Expresso.Template.Deck

  def header(assigns) do
    temple do
      div do
        span class: "header" do
          Keyword.get(@slide.metadata[:meta] || [], :section, @deck.name)
        end
      end
    end
  end

  def footer(_assigns) do
    temple do
      div do
      end
    end
  end
end

defmodule Examples.HeadingAtLeft do
  use Expresso.Template

  def render(assigns) do
    temple do
      div class: "slide-body heading-at-left" do
        h2 do: Map.get(@metadata, :heading, @name)

        div class: "slide-main" do
          c(&Expresso.Template.render_elements(&1), elements: @elements)
        end
      end
    end
  end
end

defmodule Examples.TemplateSection do
  use Expresso

  name "The factory"
  template Examples.SectionHeader
  slide_template Examples.HeadingAtLeft

  css """
  .heading-at-left h2 { border-left: 0.2rem solid var(--accent); padding-left: 0.5rem; }
  """

  slide "title" do
    heading "The factory"
    template {:builtins, :default}
  end

  slide "boxes" do
    heading "Every thing is a box"
    meta section: "Part 1: the picture"
    text_area(text: "A box has a size and a place.")
  end

  slide "cycle" do
    heading "The cycle of a machine"
    meta section: "Part 2: the loop"
    text_area(text: "Each machine takes, works and gives.")
  end
end

Examples.TemplateSection
