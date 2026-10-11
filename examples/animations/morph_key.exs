defmodule Examples.MorphKey do
  use Expresso

  slide "cover" do
    icon "coffee" do
      label "Expresso"
      size "8em"
      color :accent
      morph "brand"
    end
  end

  slide "agenda" do
    columns do
      column do
        width "25%"

        icon "coffee" do
          label "Expresso"
          size "3em"
          color :accent
          morph "brand"
        end
      end

      column do
        list do
          item "Why slides from code"
          item "The DSL"
          item "The presenter"
        end
      end
    end
  end
end

Examples.MorphKey
