defmodule Examples.FootnoteSources do
  use Expresso

  slide "processes" do
    heading "Processes"

    text_box do
      text_area do
        text "A process is cheap.<sup>1</sup>"
      end
    end

    footnote "<em>Programming Erlang</em>, chapter 12."
  end

  slide "supervisors" do
    heading "Supervisors"

    text_box do
      text_area do
        text "A supervisor starts a process again.<sup>1</sup>"
      end
    end

    footnote "The documentation of <code>Supervisor</code>."
  end
end

Examples.FootnoteSources
