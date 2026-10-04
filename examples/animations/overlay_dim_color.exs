defmodule Examples.OverlayDimColor do
  use Expresso

  css ~S"""
  .callout {
    color: color-mix(
      in srgb,
      var(--accent-dim) calc(var(--dimmed) * 100%),
      var(--accent)
    );
  }
  """

  slide "dim color" do
    heading "Dim a color of your own"

    list do
      reveal true
      dim true

      item "A point in the accent color" do
        class "callout"
      end

      item "The next point"
      item "The last point"
    end
  end
end

Examples.OverlayDimColor
