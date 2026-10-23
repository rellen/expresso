defmodule Examples.MermaidFlowchart do
  use Expresso

  root __DIR__

  slide "the release" do
    heading "The release"

    diagram "release.mmd" do
      width "80%"

      part "test", at: [from: 2]
      part "release", at: [from: 3]
      part "hex", at: [from: 4]
      part "docs", at: [from: 4]
    end
  end
end

Examples.MermaidFlowchart
