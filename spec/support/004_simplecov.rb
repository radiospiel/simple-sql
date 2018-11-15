require "simplecov"

# make sure multiple runs result in multiple result set. SimpleCov will take
# care of merging these results automatically.
SimpleCov.command_name "test:#{ENV['USE_ACTIVE_RECORD']}"

SimpleCov.start do
  # return true to remove src from coverage 
  add_filter do |src|
    src.filename =~ /\/spec\//
  end
  add_filter do |src|
    src.filename =~ /\/lib\/simple\/sql/
  end

  minimum_coverage 90
end
