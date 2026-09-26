// The parts of `gifenc` and `pngjs` that the recorder uses. The two packages
// give no types. They are CommonJS packages, so the recorder imports the
// default export of each.

declare module "gifenc" {
  type Palette = number[][];
  const gifenc: {
    quantize(rgba: Uint8Array | Uint8ClampedArray, colors: number): Palette;
    applyPalette(
      rgba: Uint8Array | Uint8ClampedArray,
      palette: Palette,
    ): Uint8Array;
    GIFEncoder(): {
      writeFrame(
        index: Uint8Array,
        width: number,
        height: number,
        options: { palette: Palette; delay: number },
      ): void;
      finish(): void;
      bytes(): Uint8Array;
    };
  };
  export default gifenc;
}

declare module "pngjs" {
  const pngjs: {
    PNG: {
      sync: {
        read(buffer: Buffer): { width: number; height: number; data: Buffer };
      };
    };
  };
  export default pngjs;
}
