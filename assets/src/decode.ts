// The decoders of the values that Elixir writes for the script.
//
// A decoder takes a value of unknown type, such as the result of `JSON.parse`.
// It returns the value with its type, or it throws a `DecodeError` that names
// the path of the wrong part, such as `$.modes[2].keys`. `schema.ts` makes a
// decoder for each form of `Expresso.Presenter.Schema` from the functions of
// this module, and it declares the type of each form.
//
// Each function returns a new decoder, and it has no other effect.
// `schema.ts` puts the annotation `@__PURE__` in front of each call, so esbuild
// keeps in the bundle only the decoders that the script uses.

export class DecodeError extends Error {
  readonly path: string;
  readonly expected: string;

  constructor(path: string, expected: string) {
    super(`${path}: expected ${expected}`);
    this.path = path;
    this.expected = expected;
  }
}

export type Decoder<T> = (value: unknown, path?: string) => T;

type Out<D> = D extends Decoder<infer T> ? T : never;

function fail(path: string, expected: string): never {
  throw new DecodeError(path, expected);
}

export const boolean: Decoder<boolean> = (value, path = "$") =>
  typeof value === "boolean" ? value : fail(path, "a boolean");

// A string. With a pattern, the string must agree with the pattern.
export function string(pattern?: RegExp): Decoder<string> {
  return (value, path = "$") =>
    typeof value === "string" && (pattern === undefined || pattern.test(value))
      ? value
      : fail(path, pattern === undefined ? "a string" : `a string ${pattern}`);
}

// An integer that is not less than `min`.
export function integer(min?: number): Decoder<number> {
  return (value, path = "$") =>
    Number.isInteger(value) && (min === undefined || (value as number) >= min)
      ? (value as number)
      : fail(path, min === undefined ? "an integer" : `an integer from ${min}`);
}

// A finite number from `min` to `max`.
export function number(min?: number, max?: number): Decoder<number> {
  return (value, path = "$") =>
    typeof value === "number" &&
    Number.isFinite(value) &&
    (min === undefined || value >= min) &&
    (max === undefined || value <= max)
      ? value
      : fail(path, `a number from ${min ?? "any"} to ${max ?? "any"}`);
}

export function literal<const T extends string | boolean | number>(
  expected: T,
): Decoder<T> {
  return (value, path = "$") =>
    value === expected ? expected : fail(path, JSON.stringify(expected));
}

// One of a list of strings.
export function oneOf<const T extends string>(
  values: readonly T[],
): Decoder<T> {
  return (value, path = "$") =>
    values.includes(value as T)
      ? (value as T)
      : fail(path, `one of ${values.join(", ")}`);
}

export function nullable<T>(decoder: Decoder<T>): Decoder<T | null> {
  return (value, path = "$") => (value === null ? null : decoder(value, path));
}

export function list<T>(decoder: Decoder<T>): Decoder<readonly T[]> {
  return (value, path = "$") =>
    Array.isArray(value)
      ? value.map((each, index) => decoder(each, `${path}[${index}]`))
      : fail(path, "an array");
}

export function tuple<const D extends readonly Decoder<unknown>[]>(
  ...decoders: D
): Decoder<{ readonly [K in keyof D]: Out<D[K]> }> {
  return (value, path = "$") => {
    if (!Array.isArray(value) || value.length !== decoders.length) {
      return fail(path, `an array of ${decoders.length}`);
    }
    return decoders.map((decoder, index) =>
      decoder(value[index], `${path}[${index}]`),
    ) as { readonly [K in keyof D]: Out<D[K]> };
  };
}

type Fields = Readonly<Record<string, Decoder<unknown>>>;
type Shape<F extends Fields> = { readonly [K in keyof F]: Out<F[K]> };

function record(value: unknown, path: string): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : fail(path, "an object");
}

// Read the keys of `fields`. The object must hold each key, unless it is
// partial. Only an open object can hold other keys, and the result does not
// hold them.
function fieldsOf(
  fields: Fields,
  mode: "exact" | "open" | "partial",
): Decoder<Record<string, unknown>> {
  return (value, path = "$") => {
    const data = record(value, path);
    if (mode !== "open") {
      for (const key of Object.keys(data)) {
        if (!(key in fields)) {
          fail(`${path}.${key}`, "no such key");
        }
      }
    }
    const result: Record<string, unknown> = {};
    for (const [key, decoder] of Object.entries(fields)) {
      if (key in data) {
        result[key] = decoder(data[key], `${path}.${key}`);
      } else if (mode !== "partial") {
        fail(`${path}.${key}`, "a value");
      }
    }
    return result;
  };
}

export function object<const F extends Fields>(fields: F): Decoder<Shape<F>> {
  return fieldsOf(fields, "exact") as Decoder<Shape<F>>;
}

export function openObject<const F extends Fields>(
  fields: F,
): Decoder<Shape<F>> {
  return fieldsOf(fields, "open") as Decoder<Shape<F>>;
}

export function partial<const F extends Fields>(
  fields: F,
): Decoder<Partial<Shape<F>>> {
  return fieldsOf(fields, "partial") as Decoder<Partial<Shape<F>>>;
}

// A value of one of the decoders, which the union tries in order. `name` goes
// into the error.
export function union<const D extends readonly Decoder<unknown>[]>(
  name: string,
  ...decoders: D
): Decoder<Out<D[number]>> {
  return (value, path = "$") => {
    for (const decoder of decoders) {
      try {
        return decoder(value, path) as Out<D[number]>;
      } catch (error) {
        if (!(error instanceof DecodeError)) {
          throw error;
        }
      }
    }
    return fail(path, name);
  };
}

// Tell if a value agrees with a decoder.
export function is<T>(decoder: Decoder<T>, value: unknown): value is T {
  try {
    decoder(value);
    return true;
  } catch (error) {
    if (error instanceof DecodeError) {
      return false;
    }
    throw error;
  }
}
