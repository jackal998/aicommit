# Contributing

We welcome and encourage contributions from everyone. Here are the guidelines if you are thinking of contributing to the project:

## Getting Started

1. Fork the repository and clone it to your local machine.
2. Create a new branch for your changes.
3. Make your changes and commit them with a descriptive and meaningful commit message.
4. Push your changes to your fork.
5. Submit a Pull Request (PR).

## Development Environment Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/aicommit.git
   cd aicommit
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Run tests:
   ```bash
   bundle exec rspec
   ```

## Project Structure

- `bin/aicommit`: Main executable for the command-line tool
- `lib/aicommit.rb`: Main module for the gem
- `lib/aicommit/version.rb`: Version information
- `lib/commit/generator.rb`: Generator for commit messages
- `lib/pr/generator.rb`: Generator for PR descriptions
- `lib/common/ai_client.rb`: Client for interacting with the OpenAI API
- `lib/common/git_client.rb`: Client for Git operations
- `lib/common/utils/ignore_file_checker.rb`: Ensures .env is in .gitignore
- `lib/common/envs/`: Environment variable management
  - `base.rb`: Base class for environment variables
  - `openai_api_key.rb`: OpenAI API key management
  - `selected_model.rb`: OpenAI model selection
  - `base_branch.rb`: Base branch configuration
  - `pr_template.rb`: PR template management
  - `pr_output_file.rb`: PR output file configuration

## Error Handling

The application uses a structured approach to error handling:

1. Centralized error handling through `Aicommit.handle_error`
2. Specific error types with the `Common::AiClient::ApiError` class
3. Categorized API errors (authentication, rate limit, server errors)
4. Context-aware error messages with helpful suggestions
5. Consistent use of colored output for better user experience

When adding new features, ensure errors are properly handled and reported back to the user with meaningful messages.

## Testing

The project uses RSpec for testing. When adding new features or fixing bugs, please ensure:

1. All existing tests pass: `bundle exec rspec`
2. New features are covered by appropriate tests
3. Test coverage is maintained or improved

The test suite includes:
- Unit tests for individual components
- Integration tests for end-to-end functionality
- Test helpers like `capture_stdout` for testing console output
- Mock objects and doubles to isolate components during testing
- Faker gem for generating test data

Use proper test structure:
- Arrange: Set up the test data and environment
- Act: Perform the action being tested
- Assert: Verify the results

## Adding Features

When adding new features, please:

1. Add appropriate tests in the `spec/` directory
2. Document the feature in the README.md
3. Ensure all existing tests pass
4. Follow the existing code style and patterns
5. Implement proper error handling
6. Consider backward compatibility

### Feature Workflow

1. Discuss the feature in an issue before implementation
2. Create a new branch for the feature
3. Implement the feature with appropriate tests
4. Update documentation
5. Submit a pull request

## PR Title Format

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

### Squash Commit Message Header
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
