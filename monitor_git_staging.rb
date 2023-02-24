require "git"

if !Dir.exist?(".git")
  raise "Not a git repository!"
end

commit_message = ""

git = Git.open(".")

diffs = git.diff.each do |diff|
  patch = diff.patch
  first_line = patch.lines.first
  last_line = patch.lines.last

  commit_message = "#{first_line} #{last_line}"
end

loop do
  puts "commit_message: #{commit_message}"
  puts "Do you want to keep this commit_message? (Y/N)"
  command = gets.chomp
  if command == "Y"
    puts "END"
    break
  elsif command == "N"
    puts "Please enter your new commit_message:"
    commit_message = gets.chomp
  else
    puts "Invalid command. Please enter Y or N."
  end
end
