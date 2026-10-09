defmodule Examples.QrCodeAt do
  use Expresso

  slide "questions" do
    heading "Questions?"

    columns do
      column do
        list do
          item "The slides"
          item "The code of the examples"
        end
      end

      column do
        qr_code "https://rellen.github.io/expresso/" do
          at from: 2
          effect :grow
          label "Scan for the slides"
        end
      end
    end
  end
end

Examples.QrCodeAt
