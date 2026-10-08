defmodule Examples.CodeConfig do
  use Expresso

  slide "the configuration" do
    heading "The configuration"

    code "toml" do
      text ~S"""
      # The server
      [server]
      host = "localhost"
      port = 8080

      [database]
      url = "postgres://localhost/app"
      pool = 10
      """

      line_numbers true
      highlight [2..4, 6..8]
    end
  end
end

Examples.CodeConfig
