defmodule Expresso.Gif.Nif do
  @moduledoc """
  The Zig NIF of `Expresso.Gif`

  `unfilter/3` removes the PNG filters of the rows of an image of 8-bit RGB.
  `encode_frame/4` encodes one frame of a GIF against the frame before it:

  1. It finds the rectangle of the pixels that are not the same as in the
     frame before. The first frame takes the whole image.
  2. It counts each exact color of the pixels that change, and median cut
     makes a palette of at most 256 colors, or 255 when the frame needs a
     transparent index. A frame with fewer colors keeps its exact colors.
  3. Each pixel of the rectangle gets the index of the box of its color. A
     pixel that does not change gets the transparent index.
  4. LZW compresses the indices, with the rules of GIFENCOD.

  Both functions run on dirty CPU schedulers. Zigler compiles the NIF with
  the Zig of the toolchain, which must be 0.16.
  """

  use Zig,
    otp_app: :expresso,
    optimize: :fast,
    nifs: [
      unfilter: [concurrency: :dirty_cpu],
      encode_frame: [concurrency: :dirty_cpu]
    ]

  # Zigler writes the library to `priv/lib`, and `_build` holds only a link to
  # `priv`. A cache of `_build` without `priv/lib` therefore holds a current
  # module and no library, and Mix does not compile the module again. Mix calls
  # this function, and it compiles the module again when the library is missing.
  @doc false
  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__? do
    not File.exists?(Application.app_dir(:expresso, "priv/lib/Elixir.Expresso.Gif.Nif.so"))
  end

  ~Z"""
  const std = @import("std");
  const beam = @import("beam");

  const Color = struct { rgb: u32, count: u32 };
  const Box = struct { start: usize, end: usize };

  const Frame = struct {
      x: u32,
      y: u32,
      width: u32,
      height: u32,
      palette: []u8,
      transparent: i32,
      code_size: u8,
      lzw: []u8,
  };

  fn channel(rgb: u32, shift: u5) u32 {
      return (rgb >> shift) & 255;
  }

  fn pixel(rgb: []const u8, i: usize) u32 {
      return (@as(u32, rgb[3 * i]) << 16) | (@as(u32, rgb[3 * i + 1]) << 8) | rgb[3 * i + 2];
  }

  fn paeth(a: i32, b: i32, c: i32) i32 {
      const p = a + b - c;
      const pa = @abs(p - a);
      const pb = @abs(p - b);
      const pc = @abs(p - c);
      if (pa <= pb and pa <= pc) return a;
      if (pb <= pc) return b;
      return c;
  }

  pub fn unfilter(rows: []const u8, width: u32, height: u32) ![]u8 {
      const stride = @as(usize, width) * 3;
      if (rows.len != height * (stride + 1)) return error.BadSize;
      const out = try beam.allocator.alloc(u8, stride * height);
      for (0..height) |y| {
          const filter = rows[y * (stride + 1)];
          const line = rows[y * (stride + 1) + 1 ..][0..stride];
          const row = out[y * stride ..][0..stride];
          for (0..stride) |x| {
              const a: i32 = if (x >= 3) row[x - 3] else 0;
              const b: i32 = if (y > 0) out[(y - 1) * stride + x] else 0;
              const c: i32 = if (x >= 3 and y > 0) out[(y - 1) * stride + x - 3] else 0;
              const predictor: i32 = switch (filter) {
                  0 => 0,
                  1 => a,
                  2 => b,
                  3 => @divFloor(a + b, 2),
                  4 => paeth(a, b, c),
                  else => return error.BadFilter,
              };
              row[x] = @truncate(@as(u32, @bitCast(@as(i32, line[x]) + predictor)));
          }
      }
      return out;
  }

  // The channel with the largest range in a box, as a shift, and the range.
  fn widest(colors: []const Color) struct { shift: u5, range: u32 } {
      var best: u5 = 16;
      var best_range: u32 = 0;
      for ([_]u5{ 16, 8, 0 }) |shift| {
          var lo: u32 = 255;
          var hi: u32 = 0;
          for (colors) |color| {
              const v = channel(color.rgb, shift);
              lo = @min(lo, v);
              hi = @max(hi, v);
          }
          if (hi >= lo and hi - lo > best_range) {
              best = shift;
              best_range = hi - lo;
          }
      }
      return .{ .shift = best, .range = best_range };
  }

  fn lessThan(shift: u5, a: Color, b: Color) bool {
      return channel(a.rgb, shift) < channel(b.rgb, shift);
  }

  const Writer = struct {
      out: std.ArrayList(u8),
      acc: u64 = 0,
      bits: u6 = 0,
      size: u5,
      next: u32,

      // Write a code with the current size, then grow the size when the
      // next free code does not fit in it.
      fn emit(self: *Writer, code: u32) !void {
          self.acc |= @as(u64, code) << self.bits;
          self.bits += self.size;
          while (self.bits >= 8) {
              try self.out.append(beam.allocator, @truncate(self.acc));
              self.acc >>= 8;
              self.bits -= 8;
          }
          if (self.next > (@as(u32, 1) << self.size) - 1 and self.size < 12) self.size += 1;
      }
  };

  // The LZW of GIF. A clear code restarts the table at 4096 codes.
  fn lzw(indices: []const u8, code_size: u5) ![]u8 {
      const clear: u32 = @as(u32, 1) << code_size;
      var table = std.AutoHashMap(u32, u32).init(beam.allocator);
      defer table.deinit();
      var w = Writer{ .out = .empty, .size = code_size + 1, .next = clear + 2 };
      try w.emit(clear);
      var current: u32 = indices[0];
      for (indices[1..]) |k| {
          const key = (current << 8) | k;
          if (table.get(key)) |code| {
              current = code;
              continue;
          }
          try w.emit(current);
          if (w.next == 4096) {
              try w.emit(clear);
              table.clearRetainingCapacity();
              w.next = clear + 2;
              w.size = code_size + 1;
          } else {
              try table.put(key, w.next);
              w.next += 1;
          }
          current = k;
      }
      try w.emit(current);
      try w.emit(clear + 1);
      if (w.bits > 0) try w.out.append(beam.allocator, @truncate(w.acc));
      return w.out.toOwnedSlice(beam.allocator);
  }

  pub fn encode_frame(rgb: []const u8, previous: []const u8, width: u32, height: u32) !Frame {
      const w: usize = width;
      const h: usize = height;
      if (rgb.len != w * h * 3) return error.BadSize;
      const diff = previous.len != 0;
      if (diff and previous.len != rgb.len) return error.BadSize;

      // The rectangle of the pixels that change. A frame that does not
      // change makes one transparent pixel.
      var x0: usize = 0;
      var y0: usize = 0;
      var x1: usize = w;
      var y1: usize = h;
      if (diff) {
          x0 = w;
          y0 = h;
          x1 = 0;
          y1 = 0;
          for (0..h) |y| {
              for (0..w) |x| {
                  const i = y * w + x;
                  if (pixel(rgb, i) != pixel(previous, i)) {
                      x0 = @min(x0, x);
                      y0 = @min(y0, y);
                      x1 = @max(x1, x + 1);
                      y1 = @max(y1, y + 1);
                  }
              }
          }
          if (x1 == 0) {
              x0 = 0;
              y0 = 0;
              x1 = 1;
              y1 = 1;
          }
      }
      const rw = x1 - x0;
      const rh = y1 - y0;

      // Count each exact color of the pixels that change.
      var counts = std.AutoHashMap(u32, u32).init(beam.allocator);
      defer counts.deinit();
      for (y0..y1) |y| {
          for (x0..x1) |x| {
              const i = y * w + x;
              const color = pixel(rgb, i);
              if (diff and color == pixel(previous, i)) continue;
              const entry = try counts.getOrPut(color);
              entry.value_ptr.* = if (entry.found_existing) entry.value_ptr.* + 1 else 1;
          }
      }
      const colors = try beam.allocator.alloc(Color, counts.count());
      defer beam.allocator.free(colors);
      var it = counts.iterator();
      var n: usize = 0;
      while (it.next()) |entry| : (n += 1) colors[n] = .{ .rgb = entry.key_ptr.*, .count = entry.value_ptr.* };

      // Median cut: split the box with the largest range at the median of
      // its pixels, until the limit or until no box can split.
      const limit: usize = if (diff) 255 else 256;
      var boxes: [256]Box = undefined;
      var count: usize = 0;
      if (colors.len > 0) {
          boxes[0] = .{ .start = 0, .end = colors.len };
          count = 1;
      }
      while (count < limit) {
          var chosen: ?usize = null;
          var chosen_range: u32 = 0;
          for (boxes[0..count], 0..) |box, i| {
              if (box.end - box.start < 2) continue;
              const range = widest(colors[box.start..box.end]).range;
              if (chosen == null or range > chosen_range) {
                  chosen = i;
                  chosen_range = range;
              }
          }
          const i = chosen orelse break;
          const box = boxes[i];
          const part = colors[box.start..box.end];
          std.mem.sort(Color, part, widest(part).shift, lessThan);
          var total: u64 = 0;
          for (part) |color| total += color.count;
          const half = (total + 1) / 2;
          var sum: u64 = 0;
          var cut: usize = 0;
          while (cut < part.len - 1 and (cut == 0 or sum < half)) : (cut += 1) sum += part[cut].count;
          boxes[i] = .{ .start = box.start, .end = box.start + cut };
          boxes[count] = .{ .start = box.start + cut, .end = box.end };
          count += 1;
      }

      // The palette is the mean of each box, and each color gets the index of its box.
      const palette = try beam.allocator.alloc(u8, count * 3);
      var index = std.AutoHashMap(u32, u8).init(beam.allocator);
      defer index.deinit();
      for (boxes[0..count], 0..) |box, i| {
          var total: u64 = 0;
          var sums = [3]u64{ 0, 0, 0 };
          for (colors[box.start..box.end]) |color| {
              total += color.count;
              for ([_]u5{ 16, 8, 0 }, 0..) |shift, c| sums[c] += @as(u64, channel(color.rgb, shift)) * color.count;
              try index.put(color.rgb, @intCast(i));
          }
          for (0..3) |c| palette[3 * i + c] = @intCast((sums[c] + total / 2) / total);
      }

      const transparent: usize = count;
      const indices = try beam.allocator.alloc(u8, rw * rh);
      defer beam.allocator.free(indices);
      for (y0..y1, 0..) |y, ry| {
          for (x0..x1, 0..) |x, rx| {
              const i = y * w + x;
              const color = pixel(rgb, i);
              indices[ry * rw + rx] = if (diff and color == pixel(previous, i))
                  @intCast(transparent)
              else
                  index.get(color).?;
          }
      }

      const entries = count + @intFromBool(diff);
      var bits: u5 = 2;
      while ((@as(usize, 1) << bits) < entries) bits += 1;
      return .{
          .x = @intCast(x0),
          .y = @intCast(y0),
          .width = @intCast(rw),
          .height = @intCast(rh),
          .palette = palette,
          .transparent = if (diff) @intCast(transparent) else -1,
          .code_size = bits,
          .lzw = try lzw(indices, bits),
      };
  }
  """
end
