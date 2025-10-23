/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  testMatch: ['**/tests/unit/**/*.test.ts'],
  moduleFileExtensions: ['ts', 'tsx', 'js'],
};

