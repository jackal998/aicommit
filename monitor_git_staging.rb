require "git"

if !Dir.exist?(".git")
  raise "Not a git repository!"
end

git = Git.open(".")
files = git.status.added

if files.empty?
  raise "No files in staging!"
end

files.each do |file|
  content = File.read(file)
  str = content[0..3999]
  first_line = str.lines.first
  last_line = str.lines.last

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
