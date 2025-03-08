class GitClient
  def initialize
    if !Dir.exist?(".git")
      puts "Not a git repository!".red
      exit
    end
  end

  def staged_changes
    git_diff_staged = `git diff --staged`

    if git_diff_staged.empty?
      exit_program("No changes detected, perhaps you didn't stage any changes?")
    else
      git_diff_staged
    end

  end

  def commit_all(message)
    `git commit -m "#{message["subject"]}" -m "#{message["description"]}"`
  end

  private

  def exit_program(message)
    puts message
    puts "exiting program."
    exit
  end
end
