defmodule Examples.ChartLevels do
  use Expresso

  root __DIR__

  slide "teams" do
    heading "Hours by team"

    chart :treemap do
      title "The hours of a week, by division and by team"
      src "hours_by_team.csv"
      levels ["Division", "Team"]
    end
  end
end

Examples.ChartLevels
