// The item at an index. A missing item stops the test with a clear message.
export function nth<T>(items: ArrayLike<T>, index: number): T {
  const item = items[index];
  if (item === undefined) {
    throw new Error(`No item at index ${index}`);
  }
  return item;
}
