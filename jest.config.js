const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver'],
    testMatch: [
        '**/__tests__/**/*.js',
        '**/tests/**/*.test.js',
        '**/?(*.)+(spec|test).js',
    ],
};
