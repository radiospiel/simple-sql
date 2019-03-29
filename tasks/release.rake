require 'bundler'
Bundler.setup

GEM_ROOT = File.expand_path('../../', __FILE__)
GEM_SPEC = "simple-sql.gemspec"

require 'simple/sql/version'
VERSION_FILE_PATH = 'lib/simple/sql/version.rb'

class VersionNumberTracker
  class << self
    def update_version_file(old_version_number, new_version_number)
      old_line = "VERSION = \"#{old_version_number}\""
      new_line = "VERSION = \"#{new_version_number}\""
      update = File.read(VERSION_FILE_PATH).gsub(old_line, new_line)
      File.open(VERSION_FILE_PATH, 'w') { |file| file.puts update }
      new_version_number
    end

    def auto_version_bump
      old_version_number = Simple::SQL::VERSION
      old = old_version_number.split('.')
      current = old[0..-2] << old[-1].next
      new_version_number = current.join('.')

      update_version_file(old_version_number, new_version_number)
    end

    def manual_version_bump
      update_version_file(Simple::SQL::VERSION, ENV['VERSION'])
    end

    def update_version_number
      @version = ENV['VERSION'] ? manual_version_bump : auto_version_bump
    end

    attr_reader :version
  end
end

namespace :release do
  task :version do
    VersionNumberTracker.update_version_number
  end

  task :build do
    Dir.chdir(GEM_ROOT) do
      sh("gem build #{GEM_SPEC}")
    end
  end

  desc "Commit changes"
  task :commit do
    Dir.chdir(GEM_ROOT) do
      version = VersionNumberTracker.version
      sh("git add #{VERSION_FILE_PATH}")
      sh("git commit -m \"bump to v#{version}\"")
      sh("git tag -a v#{version} -m \"Tag\"")
    end
  end

  desc "Push code and tags"
  task :push do
    sh("git push origin #{$TARGET_BRANCH}")
    sh('git push --tags')
  end

  desc "Cleanup"
  task :clean do
    Dir.glob(File.join(GEM_ROOT, '*.gem')).each { |f| FileUtils.rm_rf(f) }
  end

  desc "Push Gem to gemfury"
  task :publish do
    Dir.chdir(GEM_ROOT) { sh("gem push #{Dir.glob('*.gem').first}") }
  end

  task :target_master do
    $TARGET_BRANCH = 'master'
  end

  task :target_stable do
    $TARGET_BRANCH = 'stable'
  end

  task :checkout do
    sh "git status --untracked-files=no --porcelain > /dev/null || (echo '*** working dir not clean' && false)"
    sh "git checkout #{$TARGET_BRANCH}"
    sh "git pull"
  end

  task default: [
    'checkout',
    'version',
    'clean',
    'build',
    'commit',
    'push',
    'publish'
  ]

  task master: %w(target_master default)
  task stable: %w(target_stable default)
end

desc "Clean, build, commit and push"
task release: 'release:master'
