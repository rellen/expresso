defmodule Examples.Icon do
  use Expresso

  root __DIR__
  icons espresso: "icons/espresso.svg"

  slide "pipeline" do
    heading "Commit to release"

    columns do
      column do
        icon "git-commit-horizontal" do
          label "Commit"
          color :accent
        end
      end

      column do
        icon "flask-conical" do
          label "Test"
          color :success
          at from: 2
        end
      end

      column do
        icon "rocket" do
          label "Release"
          color :emphasis
          at from: 3
        end
      end

      column do
        icon "espresso" do
          label "Relax"
          at from: 4
        end
      end
    end

    text_area(text: "Each push runs :icon:circle-check: the checks before a :icon:tag: release.")
  end
end

Examples.Icon
