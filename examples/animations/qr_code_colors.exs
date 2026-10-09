defmodule Examples.QrCodeColors do
  use Expresso

  theme :gruvbox_dark_hard

  css """
  .qr-code {
    --qr-color: #3c3836;
    --qr-background: #fbf1c7;
  }
  """

  slide "the slides" do
    heading "The slides"

    qr_code "https://rellen.github.io/expresso/" do
      title "The address of the slides"
      size "25%"
    end
  end
end

Examples.QrCodeColors
