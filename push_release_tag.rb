require_relative "lib/aicommit/version"

release = Aicommit::VERSION

cmd = <<-BASH
  git checkout develop
  git fetch && git reset --hard origin/develop

  git tag #{release}
  git push origin #{release}
  git push origin #{release}:master --force-with-lease
BASH

system(cmd)
