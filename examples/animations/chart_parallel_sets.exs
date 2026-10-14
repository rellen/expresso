defmodule Examples.ChartParallelSets do
  use Expresso

  slide "titanic" do
    heading "Who survived"

    chart :parallel_sets do
      title "The 2,201 people on the Titanic, by class, by age and by survival"
      value_label "People"
      levels ["Class", "Age", "Survived"]
      reveal true

      categories [
        ["First", "Adult", "Yes"],
        ["First", "Adult", "No"],
        ["First", "Child", "Yes"],
        ["Second", "Adult", "Yes"],
        ["Second", "Adult", "No"],
        ["Second", "Child", "Yes"],
        ["Third", "Adult", "Yes"],
        ["Third", "Adult", "No"],
        ["Third", "Child", "Yes"],
        ["Third", "Child", "No"],
        ["Crew", "Adult", "Yes"],
        ["Crew", "Adult", "No"]
      ]

      series "People", [197, 122, 6, 94, 167, 24, 151, 476, 27, 52, 212, 673]
    end
  end
end

Examples.ChartParallelSets
