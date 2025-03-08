class GitClient
  def initialize
    if !Dir.exist?(".git")
      puts "Not a git repository!".red
      exit
    end
  end

  def staged_changes
    git_diff_staged = `git diff --staged`

    exit_program("No changes detected, perhaps you didn't stage any changes?") if git_diff_staged.empty?

    git_diff_staged
  end

  def diff_from_branch_root(base_branch = "main")
    merge_base = `git merge-base HEAD #{base_branch}`.strip

    if merge_base.empty?
      exit_program("Couldn't determine branch root relative to #{base_branch}")
    end

    diff = `git diff #{merge_base} HEAD`

    if diff.empty?
      exit_program("No changes detected between branch root and HEAD")
    end

    diff
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
