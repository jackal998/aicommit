require "git"

if !Dir.exist?(".git")
  raise "Not a git repository!"
end

git = Git.open(".")
diffs = git.diff.each do |diff|
  patch = diff.patch
  first_line = patch.lines.first
  last_line = patch.lines.last

  puts "First line: #{first_line}"
  puts "Last line: #{last_line}"
end

loop do
  puts "Please enter your command (type \"quit\" to exit): "
  command = gets.chomp
  if command == "quit"
    break
  else
    # 執行使用者輸入的指令
  end
end
