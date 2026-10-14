defmodule Examples.ChartSankeyFunnel do
  use Expresso

  css ".chart-node.drop { fill: var(--muted); }"

  slide "funnel" do
    heading "Where the visitors go"

    chart :sankey do
      title "The visitors of a month, from the first visit to the second year"
      value_label "People"

      flow "Visits", "Trial", 2400
      flow "Visits", "Bounced", 7600
      flow "Trial", "Paid", 600
      flow "Trial", "Left the trial", 1800
      flow "Paid", "Renewed", 450
      flow "Paid", "Cancelled", 150

      node "Bounced", label: "Left after one visit", class: "drop"
      node "Left the trial", class: "drop"
      node "Cancelled", class: "drop"
      node "Renewed", label: "Renewed for a year"
    end
  end
end

Examples.ChartSankeyFunnel
