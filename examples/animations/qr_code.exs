defmodule Examples.QrCode do
  use Expresso

  theme :dracula

  slide "the slides" do
    heading "The slides of this talk"

    qr_code "https://rellen.github.io/expresso/" do
      label "rellen.github.io/expresso"
      size "30%"
    end
  end
end

Examples.QrCode
