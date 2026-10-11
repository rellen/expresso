defmodule Examples.CalloutKinds do
  use Expresso

  slide "kinds" do
    heading "The seven kinds"

    columns do
      column do
        callout :note
        callout :tip
        callout :important
        callout :warning
      end

      column do
        callout :caution
        callout :definition
        callout :example
      end
    end
  end
end

Examples.CalloutKinds
