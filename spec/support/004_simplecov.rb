require "simplecov"

SimpleCov.start do
  # return true to remove src from coverage 
  add_filter do |src|
    next true if src.filename =~ /\/spec\//
    next true if src.filename =~ /\/immutable\.rb/

    false
  end

  minimum_coverage 90
end
