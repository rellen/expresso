defmodule Examples.ThemeMap do
  use Expresso

  theme %{
    base00: "#13233a",
    base01: "#1b2f4b",
    base02: "#27405f",
    base03: "#9fbde0",
    base04: "#a3b8d1",
    base05: "#dfe7f1",
    base06: "#eef3f9",
    base07: "#ffffff",
    base08: "#fea198",
    base09: "#faa75b",
    base0A: "#e6c45c",
    base0B: "#86ca78",
    base0C: "#69c9c9",
    base0D: "#87bdfe",
    base0E: "#cfa9fe",
    base0F: "#c47a5a"
  }

  slide "harbor" do
    heading "Harbor"

    code "elixir" do
      text ~S"""
      # Count the slides of a deck
      def count(%{slides: slides}), do: length(slides)
      """
    end

    list do
      reveal true
      dim true
      item "A dimmed item"
      item "The next item"
    end
  end
end

Examples.ThemeMap
