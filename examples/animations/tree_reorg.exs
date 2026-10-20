defmodule Examples.TreeReorg do
  use Expresso

  slide "the reorg" do
    heading "The new quality team"

    tree do
      title "The teams of the plant"

      frame "Before" do
        node "Ana" do
          detail "Plant manager"

          node "Ben" do
            detail "Production"
            node "Cy", detail: "Press"
            node "Di", detail: "Paint"
          end

          node "Eve" do
            detail "Quality"
            node "Gus", detail: "Lab"
          end
        end
      end

      frame "After" do
        node "Ana" do
          detail "Plant manager"

          node "Ben" do
            detail "Production"
            node "Cy", detail: "Press"
          end

          node "Eve" do
            detail "Quality and paint"
            node "Di", detail: "Paint"
            node "Gus", detail: "Lab"
            node "Kim", detail: "Audit"
          end
        end
      end
    end
  end
end

Examples.TreeReorg
