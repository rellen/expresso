defmodule Examples.MathEach do
  use Expresso

  # One part names each x of the polynomial, so one entry colors each x, and
  # one copy_to puts the value in the place of each x.

  slide "evaluate a polynomial" do
    heading "Evaluate a polynomial"

    math do
      tex ~S"p(x) = \part{poly}{3 \cdot x^2 + 2 \cdot x + 1}, \quad x = \part{value}{2}"

      # Each x of the polynomial, and not the x of p(x) or of x = 2.
      part "xs" do
        each "x"
        within "poly"
        on [from: 2], set: [color: "var(--accent)"]
        on [from: 3], set: [opacity: 0]
      end

      # At step 3, a copy of the value goes to each x.
      part "value" do
        on [from: 2], set: [color: "var(--success)"]
        on 3, copy_to: ["xs"]
      end

      # The copies of the value, one for each x.
      part "value@xs" do
        on [from: 3], set: [color: "var(--success)"]
      end
    end
  end
end

Examples.MathEach
