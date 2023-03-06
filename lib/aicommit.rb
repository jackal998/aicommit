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
