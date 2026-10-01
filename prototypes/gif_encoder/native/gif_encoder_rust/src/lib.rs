//! Encodes one frame of a GIF from a PNG image.
//!
//! The `png` crate decodes the image, NeuQuant of the `color_quant` crate makes a
//! palette of 256 colors, and `weezl` compresses the indices with the LZW of GIF.
//! The `gif` crate uses the same two crates.

use rustler::{Binary, Env, NewBinary, Term};

fn decode(data: &[u8]) -> Result<(u32, u32, Vec<u8>), String> {
    let mut decoder = png::Decoder::new(data);
    decoder.set_transformations(png::Transformations::EXPAND | png::Transformations::STRIP_16);
    let mut reader = decoder.read_info().map_err(|e| e.to_string())?;
    let mut buffer = vec![0; reader.output_buffer_size()];
    let info = reader.next_frame(&mut buffer).map_err(|e| e.to_string())?;
    let pixels = &buffer[..info.buffer_size()];
    // NeuQuant reads 4 bytes for each pixel.
    let rgba = match info.color_type {
        png::ColorType::Rgb => pixels.chunks_exact(3).flat_map(|p| [p[0], p[1], p[2], 255]).collect(),
        png::ColorType::Rgba => pixels.to_vec(),
        other => return Err(format!("the color type {other:?} is not RGB")),
    };
    Ok((info.width, info.height, rgba))
}

fn binary<'a>(env: Env<'a>, bytes: &[u8]) -> Binary<'a> {
    let mut binary = NewBinary::new(env, bytes.len());
    binary.as_mut_slice().copy_from_slice(bytes);
    binary.into()
}

/// Return `{width, height, palette, code_size, lzw}`, or an error text.
#[rustler::nif(schedule = "DirtyCpu")]
fn encode_frame<'a>(env: Env<'a>, png: Binary<'a>, sample: i32) -> Result<(u32, u32, Binary<'a>, u8, Binary<'a>), String> {
    let (width, height, rgba) = decode(png.as_slice())?;
    let quant = color_quant::NeuQuant::new(sample, 256, &rgba);
    let indices: Vec<u8> = rgba.chunks_exact(4).map(|p| quant.index_of(p) as u8).collect();
    let lzw = weezl::encode::Encoder::new(weezl::BitOrder::Lsb, 8)
        .encode(&indices)
        .map_err(|e| e.to_string())?;
    Ok((width, height, binary(env, &quant.color_map_rgb()), 8, binary(env, &lzw)))
}

fn load(_env: Env, _info: Term) -> bool {
    true
}

rustler::init!("Elixir.GifEncoder.Rust.Nif", load = load);
