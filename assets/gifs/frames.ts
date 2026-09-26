// The timing of the frames of a GIF. This module does not touch the browser,
// so each function has a unit test.

// The frames per second of an animation in a GIF.
export const FPS = 25;

// The time of each frame of an animation that lasts `end` milliseconds. The
// first frame comes one frame after the start, because the frame before the
// key already shows the start. The last frame shows the end. An animation of
// no time gives no frame.
export function times(end: number, fps: number = FPS): number[] {
  if (!(end > 0)) {
    return [];
  }
  const step = 1000 / fps;
  const all: number[] = [];
  for (let time = step; time < end; time += step) {
    all.push(Math.round(time));
  }
  all.push(end);
  return all;
}

// The time that a GIF shows a frame after a key, in milliseconds. The last
// key of an example gets a longer time, so a reader sees the result before
// the GIF starts again.
export function hold(last: boolean): number {
  return last ? 1600 : 900;
}

// The time that a GIF shows the first frame, before the first key.
export const START = 1200;
