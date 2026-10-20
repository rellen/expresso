defmodule Examples.TreeOrg do
  use Expresso

  slide "the plant" do
    heading "The plant"

    tree do
      title "The teams of the plant"
      color :branch
      reveal :levels
      effect :grow

      node "Ana" do
        detail "Plant manager"
        icon "factory"

        node "Ben" do
          detail "Production"
          icon "wrench"
          node "Cy", detail: "Press"
          node "Di", detail: "Paint"
        end

        node "Eve" do
          detail "Quality"
          icon "flask-conical"
          node "Gus", detail: "Lab"
        end

        node "Hal" do
          detail "Logistics"
          icon "truck"
          node "Ivy", detail: "Shipping"
        end
      end
    end
  end
end

Examples.TreeOrg
