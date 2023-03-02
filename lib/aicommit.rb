require "git"
require "openai"

def generate_commit_message(diff)
  client = OpenAI::Client.new(access_token: "YOUR_API_KEY_HERE")
  content = "Please generate a commit message based on the following diff:\n#{diff}"
  response = client.chat(
    parameters: {
      model: "gpt-3.5-turbo",
      messages: [{role: "user", content: content}]
    }
  )

  response.dig("choices", 0, "message", "content")
end

if !Dir.exist?(".git")
  raise "Not a git repository!"
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
