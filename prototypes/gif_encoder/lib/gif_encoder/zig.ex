defmodule GifEncoder.Zig do
  @moduledoc """
  Encodes a GIF with a Zig NIF

  The NIF does the steps of `GifEncoder.Elixir`: it removes the filters of the
  PNG rows, counts each exact color, makes a palette with median cut, maps each
  pixel, and compresses the indices with LZW. Erlang's `:zlib` inflates the PNG
  data first, in `GifEncoder.Png.inflate/1`. The NIF runs on a dirty CPU
  scheduler.

  Zigler compiles the NIF with the Zig of `ZIG_EXECUTABLE_PATH`, or with the
  Zig that `mix zig.get` downloads. The version must be 0.16.
  """

  use GifEncoder.PerFrame

  use Zig,
    otp_app: :gif_encoder,
    optimize: :fast,
    nifs: [encode_rows: [concurrency: :dirty_cpu]]

  alias GifEncoder.Png

  ~Z"""
  const std = @import("std");
  const beam = @import("beam");

  const Color = struct { rgb: u32, count: u32 };
  const Box = struct { start: usize, end: usize };

  const Frame = struct { palette: []u8, colors: u32, lzw: []u8 };

  fn channel(rgb: u32, shift: u5) u32 {
      return (rgb >> shift) & 255;
  }

  fn paeth(a: i32, b: i32, c: i32) u8 {
      const p = a + b - c;
      const pa = @abs(p - a);
      const pb = @abs(p - b);
      const pc = @abs(p - c);
      if (pa <= pb and pa <= pc) return @intCast(a);
      if (pb <= pc) return @intCast(b);
      return @intCast(c);
  }

  // Remove the PNG filters of 8-bit RGB rows into `out`.
  fn unfilter(rows: []const u8, width: usize, height: usize, out: []u8) !void {
      const stride = width * 3;
      if (rows.len != height * (stride + 1)) return error.BadSize;
      for (0..height) |y| {
          const filter = rows[y * (stride + 1)];
          const line = rows[y * (stride + 1) + 1 ..][0..stride];
          const row = out[y * stride ..][0..stride];
          for (0..stride) |x| {
              const a: i32 = if (x >= 3) row[x - 3] else 0;
              const b: i32 = if (y > 0) out[(y - 1) * stride + x] else 0;
              const c: i32 = if (x >= 3 and y > 0) out[(y - 1) * stride + x - 3] else 0;
              const v: i32 = line[x];
              row[x] = switch (filter) {
                  0 => line[x],
                  1 => @truncate(@as(u32, @bitCast(v + a))),
                  2 => @truncate(@as(u32, @bitCast(v + b))),
                  3 => @truncate(@as(u32, @bitCast(v + @divFloor(a + b, 2)))),
                  4 => @truncate(@as(u32, @bitCast(v + paeth(a, b, c)))),
                  else => return error.BadFilter,
              };
          }
      }
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
          if (hi - lo > best_range or (best_range == 0 and shift == 16)) {
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
      size: u6,
      next: u32,

      fn emit(self: *Writer, code: u32) !void {
          self.acc |= @as(u64, code) << self.bits;
          self.bits += self.size;
          while (self.bits >= 8) {
              try self.out.append(beam.allocator, @truncate(self.acc));
              self.acc >>= 8;
              self.bits -= 8;
          }
          if (self.next > (@as(u32, 1) << @as(u5, @intCast(self.size))) - 1 and self.size < 12) self.size += 1;
      }
  };

  // The LZW of GIF, with the rules of GIFENCOD, as in GifEncoder.Elixir.lzw/2.
  fn lzw(indices: []const u8, code_size: u6) ![]u8 {
      const clear: u32 = @as(u32, 1) << @as(u5, @intCast(code_size));
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

  pub fn encode_rows(rows: []const u8, width: u32, height: u32) !Frame {
      const pixels = @as(usize, width) * height;
      const rgb = try beam.allocator.alloc(u8, pixels * 3);
      defer beam.allocator.free(rgb);
      try unfilter(rows, width, height, rgb);

      // Count each exact color.
      var counts = std.AutoHashMap(u32, u32).init(beam.allocator);
      defer counts.deinit();
      for (0..pixels) |i| {
          const color = (@as(u32, rgb[3 * i]) << 16) | (@as(u32, rgb[3 * i + 1]) << 8) | rgb[3 * i + 2];
          const entry = try counts.getOrPut(color);
          entry.value_ptr.* = if (entry.found_existing) entry.value_ptr.* + 1 else 1;
      }
      const colors = try beam.allocator.alloc(Color, counts.count());
      defer beam.allocator.free(colors);
      var it = counts.iterator();
      var n: usize = 0;
      while (it.next()) |entry| : (n += 1) colors[n] = .{ .rgb = entry.key_ptr.*, .count = entry.value_ptr.* };

      // Median cut: split the box with the largest range at the median of
      // its pixels, until 256 boxes or no box can split.
      var boxes: [256]Box = undefined;
      boxes[0] = .{ .start = 0, .end = colors.len };
      var count: usize = 1;
      while (count < 256) {
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

      const indices = try beam.allocator.alloc(u8, pixels);
      defer beam.allocator.free(indices);
      for (0..pixels) |i| {
          const color = (@as(u32, rgb[3 * i]) << 16) | (@as(u32, rgb[3 * i + 1]) << 8) | rgb[3 * i + 2];
          indices[i] = index.get(color).?;
      }

      var bits: u5 = 2;
      while ((@as(u32, 1) << bits) < count) bits += 1;
      return .{ .palette = palette, .colors = @intCast(count), .lzw = try lzw(indices, bits) };
  }
  """

  @impl GifEncoder.PerFrame
  def encode_frame(png, _opts) do
    with {:ok, {width, height, rows}} <- Png.inflate(png) do
      %{palette: palette, colors: colors, lzw: lzw} = encode_rows(rows, width, height)

      {:ok,
       %{
         width: width,
         height: height,
         palette: palette,
         code_size: GifEncoder.Container.code_size(colors),
         lzw: lzw
       }}
    end
  end
end
