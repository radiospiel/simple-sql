require "simplecov"

# make sure multiple runs result in multiple result set. SimpleCov will take
# care of merging these results automatically.
SimpleCov.command_name "test:#{ENV['USE_ACTIVE_RECORD']}"

USE_ACTIVE_RECORD = ENV["USE_ACTIVE_RECORD"] == "1"

SimpleCov.start do
  # return true to remove src from coverage 
  add_filter do |src|
    next true if src.filename =~ /\/spec\//
    next true if src.filename =~ /\/immutable\.rb/

    next true if USE_ACTIVE_RECORD  && src.filename =~ /\/sql\/connection\/raw_connection\.rb/
    next true if !USE_ACTIVE_RECORD && src.filename =~ /\/sql\/connection\/active_record_connection\.rb/

    false
  end

  minimum_coverage 90
end
