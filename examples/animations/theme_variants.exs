defmodule Examples.ThemeVariants do
  use Expresso

  theme dark: :tokyo_night_storm, light: :solarized_light

  slide "two variants" do
    heading "Two variants"

    code "elixir" do
      text ~S"""
      # The key t shows the other variant
      def other(:light), do: :dark
      def other(:dark), do: :light
      """
    end
  end
end

Examples.ThemeVariants
