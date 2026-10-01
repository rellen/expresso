// A file for the tests of the src option of the code element.
const one = 1;
const two = 2;

function add(a, b) {
  return a + b;
}

function sum(list) {
  return list.reduce(add, 0);
}
export { sum };
