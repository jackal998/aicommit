# AI Commit

A command-line tool that uses AI to generate commit messages and PR descriptions from your code changes.

## Features

- Generate commit messages from staged changes using AI
- Generate well-structured PR descriptions in markdown format
- Support for customizing your base branch for branch comparison
- Compare changes with a specific commit SHA directly
- Interactive workflow with options to regenerate, customize, or approve AI-generated content
- Easy configuration of OpenAI API key and model selection
- Automatic .gitignore management to prevent accidental commits of sensitive data
- PR template support for generating standardized PR descriptions
- Support for saving PR descriptions to a custom location or copying to clipboard
- Enhanced error handling with helpful, context-aware error messages
- Colorized console output for better readability

## Installation

```bash
gem install aicommit
```

## Configuration

You can view your current configuration settings:

```bash
aicommit --config
```

To set your OpenAI API key:

```bash
aicommit --set-key
# or provide directly
aicommit --set-key sk-your-key-here
```

You can also configure the OpenAI model to be used:

```bash
aicommit --set-model
```

To set your base branch name for PR description generation (defaults to 'main'):

```bash
aicommit --set-base-branch
# or provide directly
aicommit --set-base-branch develop
```

To set a default PR template:

```bash
aicommit --set-pr-template
# or provide a specific template path
aicommit --set-pr-template .github/pull_request_template.md
```

To set a default output file for PR descriptions:

```bash
aicommit --set-pr-output-file
# or provide a specific filename
aicommit --set-pr-output-file docs/PR_DESCRIPTION.md
```

> **Note:** Your configuration is stored in a local `.env` file in your project directory. This file contains your OpenAI API key and should not be committed to version control. The `.env` file is automatically added to `.gitignore` to prevent accidental commits.

## Usage

### Generate Commit Messages

To generate a commit message from staged changes:

```bash
git add .
aicommit
```

The tool will:

1. Analyze your staged changes
2. Generate a commit message with a subject and description
3. Allow you to approve, regenerate, or customize the message
4. Commit your changes with the approved message

### Generate PR Descriptions

To generate a PR description based on changes from the branch root:

```bash
aicommit -p
# or
aicommit --pr-description
```

You can also specify a specific branch name or commit SHA to compare against:

```bash
# Using a branch name
aicommit -p develop

# Using a specific commit SHA
aicommit -p abc123f

# Using a full commit SHA
aicommit -p 1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t
```

This will:

1. Compare your current branch with the specified base reference (branch name or commit SHA), or with the configured base branch, or with 'main' by default
2. Generate a well-structured PR description in markdown format with:
   - A concise PR title
   - Overview of changes
   - Implementation details
   - Technical decisions
   - Proper markdown formatting (headings, lists, code blocks)
3. Save the approved PR description to a `PR_DESCRIPTION.md` file in your current directory (or your configured output file)

You can customize the output destination:

```bash
# Save to a specific filename
aicommit -p -f my_pr.md
# or
aicommit -p --pr-output-file my_pr.md

# Copy to clipboard instead of saving to a file
aicommit -p -c
# or
aicommit -p --pr-output-clipboard

# Both save to file and copy to clipboard
aicommit -p -f -c

# Save to a specific file and copy to clipboard
aicommit -p -f custom_pr.md -c
```

You can also use GitHub PR templates:

```bash
# Use a template for this run only (interactive selection if multiple exist)
aicommit -p -t
# or
aicommit -p --pr-template

# Use a specific template file
aicommit -p -t .github/PULL_REQUEST_TEMPLATE/feature.md
```

## Command-Line Options

### Basic options
- `-v`, `--version`: Show the current version
- `-h`, `--help`: Show help message

### PR Description options
- `-p [BASE_REF]`, `--pr-description [BASE_REF]`: Generate a PR description, optionally specify a base ref (branch name or commit SHA)
- `-f [FILENAME]`, `--pr-output-file [FILENAME]`: Save PR description to a file (default: `PR_DESCRIPTION.md`)
- `-c`, `--pr-output-clipboard`: Copy PR description to clipboard
- `-t [TEMPLATE_PATH]`, `--pr-template [TEMPLATE_PATH]`: Use GitHub PR template in generation, optionally specify a custom template path

### Configuration options
- `--config`: Show current configuration
- `--set-key [KEY]`: Set OpenAI API key
- `--set-model [MODEL]`: Set OpenAI model
- `--set-base-branch [BASE_BRANCH]`: Set default base branch name
- `--set-pr-output-file [FILENAME]`: Set default PR output filename
- `--set-pr-template [TEMPLATE_PATH]`: Set default PR template path

## Security

AI Commit includes several security features:

- Your OpenAI API key is stored in a local `.env` file
- The tool automatically adds `.env` to your `.gitignore` file to prevent accidental exposure
- No data is stored or sent anywhere except directly to the OpenAI API

## Requirements

- Git repository
- Ruby 2.7 or higher
- OpenAI API key

## Development

To contribute to this project:

1. Clone the repository
2. Install dependencies with `bundle install`
3. Run tests with `bundle exec rspec`

For more detailed information about contributing, see [CONTRIBUTION.md](CONTRIBUTION.md).

## License

See the [LICENSE](LICENSE) file for license rights and limitations.
