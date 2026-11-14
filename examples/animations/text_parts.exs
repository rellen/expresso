defmodule Examples.TextParts do
  use Expresso

  slide "parts" do
    heading "A question"

    text_box do
      text_area(
        text: """
        The answer is <span at="2-">42</span>.
        It is <em at="3" state="alert">not</em> 41.
        """
      )
    end

    list do
      item ~s(We asked <b at="4-">two times</b>.)
    end
  end
end

Examples.TextParts
