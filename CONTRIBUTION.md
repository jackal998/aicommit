# Contributing

We welcome and encourage contributions from everyone. Here are the guidelines if you are thinking of contributing to the project:

## Getting Started

1. Fork the repository and clone it to your local machine.
2. Create a new branch for your changes.
3. Make your changes and commit them with a descriptive and meaningful commit message.
4. Push your changes to your fork.
5. Submit a Pull Request (PR).

## PR title Format

When submitting a PR, please make sure to provide a detailed description and conventional PR title of your changes. The PR should include the relevant issue numbers, and a list of the changes that were made.

We use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#summary) and [conventional-pr-title-action](https://github.com/aslafy-z/conventional-pr-title-action#conventional-pr-title-action) to keep our commit messages easy to read and organized. The format consists of a type, optional scope, short summary, and optional body and footer.

The type of the commit is one of the following:

- `fix` for a bug fix
- `feat` for a new feature
- `docs` for changes to documentation
- `style` for formatting, missing semi colons, etc; no code change
- `refactor` for refactoring production code
- `test` for adding tests, refactoring test; no production code change
- `ci` for changes to CI configuration files and scripts
- `chore` for other changes that don't modify src or test files

The scope should be the name of the affected module (e.g. `ci`, `docs`, `server`, etc).

The summary should be a short description of the changes (no more than 50 characters).

The body should provide a detailed description of the changes. If the commit has breaking changes, the body should include `BREAKING CHANGE:` followed by a description of the change.

The footer should include any relevant information such as related pull requests, issues, or notes for release.

#### Squash Commit Message Header
```
<type>(<scope>): <short summary> (#<PR number>)
  │       │             │          │
  │       │             │          └─⫸ The PR number that connects it with the squashed commit.
  │       │             │
  │       │             └─⫸ Summary in present tense. Not capitalized. No period at the end.
  │       │
  │       └─⫸ Commit Scope: category or sub type
  │
  └─⫸ Commit Type: fix|feat|docs|refactor|ci|perf|chore|
```
Examples:

- `fix(server): fix memory leak`
- `feat(ci): add automated tests`
- `docs: update contributing guidelines`
- `refactor: rename function foo() to bar()`
- `ci: add Travis CI integration`
- `chore: remove unused files`

For breaking changes, the following should be used:

- `feat!: add new feature`
- `fix!: fix memory leak`

## Commit Message

We encourage you to add your full branch name in front of your commits

- `ci/travis-integration: add Travis config files`
- `chore/unused-files: remove unused documents`
