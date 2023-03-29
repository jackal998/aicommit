class GitClient
  def initialize
    if !Dir.exist?(".git")
      puts "Not a git repository!".red
      exit
    end
  end

  def git_diff_str
    git_diff_str = `git diff --staged`

    if git_diff_str.empty?
      puts "No changes detected, exiting program."
      exit
    end

    git_diff_str
  end

  def commit_all(message)
    `git commit -m "#{message}"`
  end
end
