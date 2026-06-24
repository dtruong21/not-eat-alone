const expo = require('eslint-config-expo/flat');

module.exports = [
  ...expo,
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/consistent-type-imports': 'warn',
    },
    ignores: ['node_modules', '.expo', 'dist'],
  },
];
