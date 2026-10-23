defmodule Examples.MermaidSequence do
  use Expresso

  slide "a request" do
    heading "A request"

    diagram do
      lang :mermaid
      width "70%"

      source """
      sequenceDiagram
        participant Browser
        participant Web
        participant DB
        Browser->>Web: GET /deck
        Web->>DB: read the slides
        DB-->>Web: the slides
        Web-->>Browser: the HTML
      """

      part "Browser->Web", at: [from: 1]
      part "Web->DB", at: [from: 2]
      part "DB->Web", at: [from: 3]
      part "Web->Browser", at: [from: 4]
    end
  end
end

Examples.MermaidSequence
