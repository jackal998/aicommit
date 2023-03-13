class GitClient
  def initialize
    if !Dir.exist?(".git")
      puts "Not a git repository!"
      exit
    end

    @git = Git.open(".")
  end

  def get_patch_str
    if current_branch.nil?
      puts "No HEAD detected, please add your first commit, exiting program."
      exit
    end

    patch_str = ""
    @git.diff.each do |diff|
      patch = diff.patch
      patch_str += "\n\n#{diff.path}\n"
      patch_str += patch
    end

    if patch_str.nil? || patch_str.strip.empty?
      puts "No changes detected, exiting program."
      exit
    end

    patch_str
  end

  def commit_all(message)
    @git.commit_all(message)
  end

  private

  def current_branch
    @git.current_branch
  end
end
