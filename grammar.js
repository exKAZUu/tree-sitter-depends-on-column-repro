module.exports = grammar({
  name: 'column',
  externals: ($) => [$.head, $.tail],
  extras: () => [],
  rules: {
    document: ($) => repeat(choice($.head, $.tail, $.word, $.newline)),
    word: () => /[a-w]+/,
    newline: () => '\n',
  },
});
