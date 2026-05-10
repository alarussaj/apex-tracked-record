# Contributing

Thanks for considering a contribution to **apex-tracked-record**.

## Development setup

You'll need:

- [Node.js](https://nodejs.org/) 18 or later
- [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli) (`sf`)
- A Salesforce **Dev Hub** org (a free [Developer Edition](https://developer.salesforce.com/signup) works)

### One-time setup

```bash
# Clone the repo
git clone https://github.com/alarussaj/apex-tracked-record.git
cd apex-tracked-record

# Install Node dependencies (Prettier, plugins)
npm install

# Authorize your Dev Hub
sf org login web --set-default-dev-hub --alias DevHub
```

### Running tests locally

```bash
# Create a scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias atr-scratch --set-default --duration-days 7

# Deploy the source
sf project deploy start --target-org atr-scratch

# Run the tests
sf apex run test --target-org atr-scratch --code-coverage --result-format human --wait 10
```

### Formatting

This project uses [Prettier](https://prettier.io/) with [`prettier-plugin-apex`](https://github.com/dangmai/prettier-plugin-apex).

```bash
# Format all files
npm run format

# Check formatting without changing files (matches CI)
npm run format:check
```

CI will reject pull requests with unformatted files. Run `npm run format` before pushing.

### Static analysis (PMD)

The project uses a custom PMD ruleset (see `ruleset.xml`). PMD runs in CI on every pull request.

To run PMD locally:

```bash
# Download PMD if you haven't already (https://pmd.github.io/)
pmd check -d force-app -R ruleset.xml -f text
```

## Pull request process

1. **Fork** the repo and create a feature branch from `main`:
   ```bash
   git checkout -b feature/short-description
   ```
2. **Make your changes** with tests covering new behavior.
3. **Run formatting and tests** locally before pushing.
4. **Open a pull request** against `main`. Fill in the PR template.
5. **CI must pass** — scratch org deploy, all Apex tests, PMD, Prettier check, code coverage.
6. **Wait for review.** I'll typically respond within a few days.

## Coding standards

- **Visibility**: All public types use `public` (the library is source-distributed and not a managed package).
- **Sharing**: Concrete classes that don't perform DML use `inherited sharing`. The library doesn't perform DML, so this is the default everywhere.
- **ApexDoc**: Every public method has `@description`, `@param`, `@return`, and `@throws` tags as appropriate. Private methods that perform meaningful logic also have ApexDoc.
- **Tests**: Use the `Assert` class (not `System.assert`). Every assertion has a descriptive message. Test methods follow `shouldDoThingWhenCondition` naming. Use the `// Arrange`, `// Act`, `// Assert` block comments where they aid readability.
- **No empty lines inside method bodies.** If a separation is meaningful, add a comment explaining why.

## Reporting issues

Please use the [issue templates](https://github.com/alarussaj/apex-tracked-record/issues/new/choose):

- **Bug report** — for unexpected behavior.
- **Feature request** — for new functionality.

Include a minimal reproduction case for bugs. The smaller the better.

## Versioning

This project uses [Semantic Versioning](https://semver.org/). Releases are tagged `vMAJOR.MINOR.PATCH`. PR labels (`bug`, `enhancement`, `breaking`) drive automatic release-notes drafting.

## Code of Conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
