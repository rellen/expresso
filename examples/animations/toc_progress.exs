defmodule Examples.TocProgress do
  use Expresso

  slide "why" do
    section "Why"
    heading "Why"
  end

  slide "build" do
    section "Build"
    heading "Build"
  end

  slide "progress" do
    section "Test"
    heading "The progress option"

    columns do
      column do
        text_area(text: "Dim the rest")
        toc()
      end

      column do
        text_area(text: "Dim earlier")

        toc do
          progress :dim_earlier
        end
      end

      column do
        text_area(text: "Check earlier")

        toc do
          progress :check_earlier
        end
      end

      column do
        text_area(text: "Strike earlier")

        toc do
          progress :strike_earlier
        end
      end
    end
  end

  slide "deploy" do
    section "Deploy"
    heading "Deploy"
  end
end

Examples.TocProgress
