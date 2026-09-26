defmodule Examples.OverlayCustom do
  use Expresso

  css ~S"""
  @keyframes bounce {
    0% { transform: scale(0.3); }
    60% { transform: scale(1.15); }
    100% { transform: scale(1); }
  }

  [data-effect="bounce"] {
    --enter-animation: bounce;
  }

  [data-effect="drop"] {
    --enter-y: -3rem;
  }

  .text-box {
    background: color-mix(in srgb, #ffe066 calc(var(--mark, 0) * 100%), transparent);
  }
  """

  slide "custom" do
    heading "The CSS of a deck"

    text_box do
      at from: 2
      effect :bounce
      text_area(text: "Bounce at step 2")
    end

    text_box do
      at from: 3
      effect :drop
      text_area(text: "Drop at step 3")
    end

    text_box do
      on 4, state: :mark
      text_area(text: "A marker at step 4")
    end
  end
end

Examples.OverlayCustom
