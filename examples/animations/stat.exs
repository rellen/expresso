defmodule Examples.Stat do
  use Expresso

  slide "intro" do
    heading "This year"
  end

  slide "results" do
    heading "This year"

    columns do
      column do
        stat 1250 do
          label "orders"
          count true
        end
      end

      column do
        stat 98.6 do
          label "on time"
          suffix "%"
          count true
        end
      end

      column do
        stat 4.2 do
          label "revenue"
          prefix "$"
          suffix "M"
          count true
          at from: 2
        end
      end
    end
  end
end

Examples.Stat
