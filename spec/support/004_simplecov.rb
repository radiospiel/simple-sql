require "simplecov"

SimpleCov.start do
  # add_filter do |src|
  #   # paths = %w(auth authentication authorization).map do |library_name|
  #   #   File.expand_path("../../#{library_name}/lib", __FILE__)
  #   # end
  #
  #   !paths.any? { |path| src.filename =~ /^#{Regexp.escape(path)}/ }
  # end

  minimum_coverage 96
end
