module.exports = {
    root: true,
    plugins: ["prettier"],
    extends: ["eslint:recommended"],
    rules: {
      "comma-spacing": ["error", {before: false, after: true}],
      "prettier/prettier": "error",
    },
    parserOptions: {
      ecmaVersion: 2020
    },
    env: {
      es6: true,
      node: true,
      mocha: true
    }
  };