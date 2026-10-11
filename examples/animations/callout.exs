defmodule Examples.Callout do
  use Expresso

  slide "deploy" do
    heading "Deploy a release"

    callout :note do
      text_area(text: "The release holds the runtime of Erlang.")
    end

    callout :tip do
      at from: 2
      text_area(text: "Build it on the system of the server.")
    end

    callout :warning do
      at from: 3
      text_area(text: "A hot upgrade needs an appup file.")
    end
  end
end

Examples.Callout
