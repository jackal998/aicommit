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

  def diff_from_branch_root(base_ref = "main")
    base_commit =
      if is_commit_sha?(base_ref)
        base_ref
      else
        `git merge-base HEAD #{base_ref}`.strip
      end

    exit_program("Couldn't determine base commit relative to #{base_ref}") if base_commit.empty?

    diff = `git diff #{base_commit} HEAD`

    exit_program("No changes detected between base commit and HEAD") if diff.empty?

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

  def is_commit_sha?(ref)
    return false unless ref.match?(/^[0-9a-f]{7,40}$/i)

    output = `git cat-file -t #{ref}`
    output.strip == "commit"
  end
end
