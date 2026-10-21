defmodule Examples.GraphGraphviz do
  use Expresso

  root __DIR__

  slide "the system" do
    heading "The system"

    diagram "system.dot" do
      width "80%"

      part "api", at: [from: 2]
      part "db", at: [from: 3]
      part "queue", at: [from: 3]
      part "worker", at: [from: 4]
    end
  end
end

Examples.GraphGraphviz
