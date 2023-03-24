cmd = <<-BASH
  git checkout develop
  git fetch && git reset --hard origin/develop
  export release=$(ruby -e "require_relative 'lib/aicommit/version'; puts Aicommit::VERSION")

  git tag ${release}
  git push origin ${release}
  git push origin ${release}:master --force-with-lease
BASH

system(cmd)
