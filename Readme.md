# AI Commit

A command-line tool that uses AI to generate commit messages and PR descriptions from your code changes.

## Features

- Generate commit messages from staged changes using AI
- Generate well-structured PR descriptions in markdown format
- Support for customizing your main branch name for branch comparison
- Interactive workflow with options to regenerate, customize, or approve AI-generated content
- Easy configuration of OpenAI API key and model selection

## Installation

```bash
gem install aicommit
```

## Configuration

Before using the tool, you need to set your OpenAI API key:

```bash
aicommit --key
```

You can also configure the OpenAI model to be used:

```bash
aicommit --model
```

To set your main branch name for PR description generation (defaults to 'main'):

```bash
aicommit --main-branch
```

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
aicommit -pd
# or
aicommit --pr-description
```

This will:
1. Compare your current branch with the main branch (or your configured main branch)
2. Generate a well-structured PR description in markdown format with:
   - A concise PR title
   - Overview of changes
   - Implementation details
   - Technical decisions
   - Proper markdown formatting (headings, lists, code blocks)
3. Allow you to:
   - Approve the description (Y)
   - Regenerate a new description (R)
   - Create your own custom description (N)
   - Quit without saving (Q)
4. Save the approved PR description to a `PR_DESCRIPTION.md` file in your current directory

## Command-Line Options

- `-v`, `--version`: Show the current version
- `--key`: Set or update your OpenAI API key
- `--model`: Set or update the OpenAI model
- `--main-branch`: Set or update your main branch name
- `-pd`, `--pr-description`: Generate a PR description

## Requirements

- Git repository
- Ruby 2.6 or higher
- OpenAI API key

## Development

To contribute to this project:

1. Clone the repository
2. Install dependencies with `bundle install`
3. Run tests with `bundle exec rspec`

## License

See the [LICENSE](LICENSE) file for license rights and limitations. 
