defmodule Examples.FootnoteAt do
  use Expresso

  slide "two claims" do
    heading "Two claims"

    list do
      reveal true
      item "BEAM processes are cheap.<sup>1</sup>"
      item "A crash stays in its process.<sup>2</sup>"
    end

    footnote "Approximately 2.6 kB of memory for each new process."
    footnote "The supervisor starts the process again.", at: [from: 2]
  end
end

Examples.FootnoteAt
