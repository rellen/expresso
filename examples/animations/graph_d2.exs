defmodule Examples.GraphD2 do
  use Expresso

  root __DIR__

  slide "the system" do
    heading "The system"

    diagram "system.d2" do
      width "80%"

      part "app.api", at: [from: 2]
      part "db", at: [from: 2]
      part "queue", at: [from: 3]
      part "worker", at: [from: 3]

      part "app" do
        on 4, state: :alert
      end
    end
  end
end

Examples.GraphD2
