請參考以下格式

# Contributing

## Git Workflow

1. branch from `develop` with branch name including pre-fix branch types: 
(see the commit types below)
    ```
    <types>/<branch_name>:
    ci/add-git-flow
    docs/add-contribution
    ```
2. make commits with full branch name:
    ```
    <types>/<branch_name>: commit
    ci/add-git-flow: add ci yml
    docs/add-contribution: add contribution.md
    ```

3. make a conventional PR title (see below) with at least 1 reviewer(s)
4. merge the PR using `Squash and merge` option with changed commit message after last approval

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
  └─⫸ Commit Type: build|ci|docs|feat|fix|perf|refactor|test
```
The `<type>` and `<summary>` fields are mandatory, the `(<scope>)` field is optional.
You can also add `!` before `:` to indicate breaking changes.

More details please check:
https://www.conventionalcommits.org/en/v1.0.0-beta.4/#specification

以及以下內容

Conventional Commits 1.0.0-beta.4
Summary
The Conventional Commits specification is a lightweight convention on top of commit messages. It provides an easy set of rules for creating an explicit commit history; which makes it easier to write automated tools on top of. This convention dovetails with SemVer, by describing the features, fixes, and breaking changes made in commit messages.

The commit message should be structured as follows:

<type>[optional scope]: <description>

[optional body]

[optional footer]
The commit contains the following structural elements, to communicate intent to the consumers of your library:

fix: a commit of the type fix patches a bug in your codebase (this correlates with PATCH in semantic versioning).
feat: a commit of the type feat introduces a new feature to the codebase (this correlates with MINOR in semantic versioning).
BREAKING CHANGE: a commit that has the text BREAKING CHANGE: at the beginning of its optional body or footer section introduces a breaking API change (correlating with MAJOR in semantic versioning). A BREAKING CHANGE can be part of commits of any type.
Others: commit types other than fix: and feat: are allowed, for example @commitlint/config-conventional (based on the Angular convention) recommends chore:, docs:, style:, refactor:, perf:, test:, and others.
We also recommend improvement for commits that improve a current implementation without adding a new feature or fixing a bug. Notice these types are not mandated by the conventional commits specification, and have no implicit effect in semantic versioning (unless they include a BREAKING CHANGE). A scope may be provided to a commit’s type, to provide additional contextual information and is contained within parenthesis, e.g., feat(parser): add ability to parse arrays.

Examples
Commit message with description and breaking change in body
feat: allow provided config object to extend other configs

BREAKING CHANGE: `extends` key in config file is now used for extending other config files
Commit message with optional ! to draw attention to breaking change
chore!: drop Node 6 from testing matrix

BREAKING CHANGE: dropping Node 6 which hits end of life in April
Commit message with no body
docs: correct spelling of CHANGELOG
Commit message with scope
feat(lang): add polish language
Commit message for a fix using an (optional) issue number.
fix: correct minor typos in code

see the issue for details on the typos fixed

closes issue #12
Specification
The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be interpreted as described in RFC 2119.

Commits MUST be prefixed with a type, which consists of a noun, feat, fix, etc., followed by an OPTIONAL scope, and a REQUIRED terminal colon and space.
The type feat MUST be used when a commit adds a new feature to your application or library.
The type fix MUST be used when a commit represents a bug fix for your application.
A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parenthesis, e.g., fix(parser):
A description MUST immediately follow the space after the type/scope prefix. The description is a short summary of the code changes, e.g., fix: array parsing issue when multiple spaces were contained in string.
A longer commit body MAY be provided after the short description, providing additional contextual information about the code changes. The body MUST begin one blank line after the description.
A footer of one or more lines MAY be provided one blank line after the body. The footer MUST contain meta-information about the commit, e.g., related pull-requests, reviewers, breaking changes, with one piece of meta-information per-line.
Breaking changes MUST be indicated at the very beginning of the body section, or at the beginning of a line in the footer section. A breaking change MUST consist of the uppercase text BREAKING CHANGE, followed by a colon and a space.
A description MUST be provided after the BREAKING CHANGE: , describing what has changed about the API, e.g., BREAKING CHANGE: environment variables now take precedence over config files.
Types other than feat and fix MAY be used in your commit messages.
The units of information that make up conventional commits MUST NOT be treated as case sensitive by implementors, with the exception of BREAKING CHANGE which MUST be uppercase.
A ! MAY be appended prior to the : in the type/scope prefix, to further draw attention to breaking changes. BREAKING CHANGE: description MUST also be included in the body or footer, along with the ! in the prefix.
Why Use Conventional Commits
Automatically generating CHANGELOGs.
Automatically determining a semantic version bump (based on the types of commits landed).
Communicating the nature of changes to teammates, the public, and other stakeholders.
Triggering build and publish processes.
Making it easier for people to contribute to your projects, by allowing them to explore a more structured commit history.
FAQ
How should I deal with commit messages in the initial development phase?
We recommend that you proceed as if you’ve already released the product. Typically somebody, even if it’s your fellow software developers, is using your software. They’ll want to know what’s fixed, what breaks etc.

Are the types in the commit title uppercase or lowercase?
Any casing may be used, but it’s best to be consistent.

What do I do if the commit conforms to more than one of the commit types?
Go back and make multiple commits whenever possible. Part of the benefit of Conventional Commits is its ability to drive us to make more organized commits and PRs.

Doesn’t this discourage rapid development and fast iteration?
It discourages moving fast in a disorganized way. It helps you be able to move fast long term across multiple projects with varied contributors.

Might Conventional Commits lead developers to limit the type of commits they make because they’ll be thinking in the types provided?
Conventional Commits encourages us to make more of certain types of commits such as fixes. Other than that, the flexibility of Conventional Commits allows your team to come up with their own types and change those types over time.

How does this relate to SemVer?
fix type commits should be translated to PATCH releases. feat type commits should be translated to MINOR releases. Commits with BREAKING CHANGE in the commits, regardless of type, should be translated to MAJOR releases.

How should I version my extensions to the Conventional Commits Specification, e.g. @jameswomack/conventional-commit-spec?
We recommend using SemVer to release your own extensions to this specification (and encourage you to make these extensions!)

What do I do if I accidentally use the wrong commit type?
When you used a type that’s of the spec but not the correct type, e.g. fix instead of feat
Prior to merging or releasing the mistake, we recommend using git rebase -i to edit the commit history. After release, the cleanup will be different according to what tools and processes you use.

When you used a type not of the spec, e.g. feet instead of feat
In a worst case scenario, it’s not the end of the world if a commit lands that does not meet the conventional commit specification. It simply means that commit will be missed by tools that are based on the spec.

Do all my contributors need to use the conventional commit specification?
No! If you use a squash based workflow on Git lead maintainers can clean up the commit messages as they’re merged—adding no workload to casual committers. A common workflow for this is to have your git system automatically squash commits from a pull request and present a form for the lead maintainer to enter the proper git commit message for the merge.

幫我重新生成一份可以讓沒有使用過git的人也能照著步驟進行的contribution guidelines，以不超過兩千字為限（英文）

# Contributing

We welcome and encourage contributions from everyone. Here are the guidelines if you are thinking of contributing to the project:

## Getting Started

1. Fork the repository and clone it to your local machine.
2. Create a new branch for your changes.
3. Make your changes and commit them with a descriptive and meaningful commit message.
4. Push your changes to your fork.
5. Submit a Pull Request (PR).

## Commit Message Format

We use a conventional commit format to keep our commit messages easy to read and organized. The format consists of a type, optional scope, short summary, and optional body and footer.

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

Examples:

- `fix(server): fix memory leak`
- `feat(ci): add automated tests`
- `docs: update contributing guidelines`
- `style: add semicolon to end of line`
- `refactor: rename function foo() to bar()`
- `test: add test for function foo()`
- `ci: add Travis CI integration`
- `chore: remove unused files`

For breaking changes, the following should be used:

- `feat!: add new feature`
- `fix!: fix memory leak`

## Pull Request

When submitting a PR, please make sure to provide a detailed description of your changes. The PR should include the relevant issue numbers, and a list of the changes that were made.

## Code of Conduct

We strive to create an open and welcoming environment for everyone. Please read our [Code of Conduct](https://github.com/your-organization/your-project/CODE_OF_CONDUCT.md) for more information.

## License

By contributing to this project, you agree to the license and copyright terms outlined in the [LICENSE](https://github.com/your-organization/your-project/LICENSE) file.
