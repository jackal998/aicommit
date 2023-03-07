# AICommit
Use your own spell against you.

## Setup
### Prerequisites
- Ruby 2.5 or later
- An OpenAI API key

### Installation
Install the aicommit gem:
```bash
gem install aicommit
```
### Upgrading
To upgrade to the latest version of AICommit, run:

```bash
gem update aicommit
```

### Usage
#### Generate a commit message
To generate a commit message based on the changes in your Git repository:

1. Run the following command at the root of your project:
    ```bash
    aicommit
    ```

2. The AI model will generate a commit message based on the changes in your Git repository.

3. Review the generated commit message.

4. To commit the changes with the generated commit message, enter Y at the prompt.
To enter a new commit message, enter N.
To quit without committing, enter Q.

#### Uninstallation
To uninstall AICommit, run:

```bash
gem uninstall aicommit
```
### How it works
AICommit uses OpenAI's GPT-3.5 AI model to generate commit messages based on the changes in your Git repository.

### Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

### License
This project is licensed under the MIT License - see the LICENSE.md file for details.
