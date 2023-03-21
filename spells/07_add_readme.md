Prompt:
請問，根據我們現在的code，你有建議的readme.md的內容嗎？
```ruby
require "git"
require "openai"
require "dotenv/load"

def save_api_key_to_env
  puts "Please enter your OpenAI API key (or 'q' to quit):"
  api_key = gets.chomp
  if api_key.downcase == "q"
    puts "Exiting program."
    exit
  end
  File.write(".env", "OPENAI_API_KEY=#{api_key}")
  ENV["OPENAI_API_KEY"] = api_key
  puts "Your API key has been saved to .env"
end

def generate_commit_message(diff)
  diff = diff[-3800..] || diff
  client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  content = "Please generate a commit message based on the following diff in one sentance and less than 80 letters:\n#{diff}"

  response = client.chat(
    parameters: {
      model: "gpt-3.5-turbo",
      messages: [{role: "user", content: content}]
    }
  )

  if response.code == 401
    puts "Invalid API key."
    save_api_key_to_env

    return generate_commit_message(diff)
  end

  response.dig("choices", 0, "message", "content")
end

if !Dir.exist?(".git")
  raise "Not a git repository!"
end

if ENV["OPENAI_API_KEY"].nil?
  save_api_key_to_env
end

patch_str = ""

git = Git.open(".")
git.diff.each do |diff|
  patch = diff.patch
  patch_str += "\n\n#{diff.path}\n"
  patch_str += patch
end

commit_message = generate_commit_message(patch_str)

loop do
  puts "commit_message: #{commit_message}"
  puts "Do you want to keep this commit_message? (Y/N) (or Q to quit)"
  command = gets.chomp
  if command.match?(/^[Yy]$/)
    git.commit_all(commit_message)
    puts "Committed all changes with message: #{commit_message}"
    break
  elsif command.match?(/^[Nn]$/)
    puts "Please enter your new commit_message:"
    commit_message = gets.chomp
  elsif command.match?(/^[Qq]$/)
    puts "Quit without committing."
    exit
  else
    puts "Invalid command. Please enter Y, N, or Q."
  end
end
```
我想要參考下面這種格式：
## Setup
> The minimum supported version ...
1. Install _aicommits_:
2. ...

### Upgrading

Check the installed version with:
```
...
```
## Usage
...

#### Install

In the Git repository ...

#### Uninstall
In the Git repository ...

#### Usage

1. Stage your files and commit:
2. ...

## How it works

This tool ...

ChatGPT:
Sure! Here's a sample README.md based on your code:

AICommits
Use your own spell against you.

Setup
Prerequisites
Ruby 2.5 or later
Git 1.14 or later
An OpenAI API key
Installation
Install the aicommits gem:

```bash
gem install aicommits
```
Create a .env file at the root of your project and add your OpenAI API key:

```bash
echo "OPENAI_API_KEY=your-api-key" > .env
```
Upgrading
To upgrade to the latest version of AICommits, run:

```bash
gem update aicommits
```
Usage
Generate a commit message
To generate a commit message based on the changes in your Git repository:

Run the following command at the root of your project:

```bash
aicommit
```
The AI model will generate a commit message based on the changes in your Git repository.

Review the generated commit message.

To commit the changes with the generated commit message, enter Y at the prompt.

To enter a new commit message, enter N.

To quit without committing, enter Q.

Uninstallation
To uninstall AICommits, run:

```bash
gem uninstall aicommits
```
How it works
AICommits uses OpenAI's GPT-3 AI model to generate commit messages based on the changes in your Git repository.

Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

License
This project is licensed under the MIT License - see the LICENSE.md file for details.
