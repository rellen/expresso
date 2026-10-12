defmodule Examples.CodeLongLines do
  use Expresso

  slide "the reservation" do
    heading "Book the floor"

    code "js" do
      text """
      // anyone else's booking that meets b: the one that ends last
      function resHit(m, b) {
        let hit = null;               // (the latest booking that meets b)
        for (const [who, r] of RES) {
          if (who === m || r.t1 <= b.t0 || b.t1 <= r.t0 || !boxesMeet(r, b)) continue;
          for (const q of r.list) if (q.t0 < b.t1 && b.t0 < q.t1 && boxesMeet(q, b) && (!hit || q.t1 > hit.t1)) hit = { who, q };
        }
        return hit;                   // (null when the floor is free)
      }
      """

      trailing_comments false
      wrap true
    end
  end
end

Examples.CodeLongLines
