# private
module Simple::SQL::Helpers::Encoder
  extend self

  def encode_args(connection, args)
    args.map { |arg| encode_arg(connection, arg) }
  end

  def encode_arg(connection, arg)
    return arg unless arg.is_a?(Array)
    return "{}" if arg.empty?

    encoded_ary = encode_array(connection, arg)
    "{" + encoded_ary.join(",") + "}"
  end

  def encode_array(connection, ary)
    case ary.first
    when String
      ary.map do |str|
        str = connection.escape(str)

        # These fixes have been discovered during tests. see spec/simple/sql/conversion_spec.rb
        str = str.gsub("\"", "\\\"")
        str = str.gsub("''", "'")
        "\"#{str}\""
      end
    when Integer
      ary
    else
      raise ArgumentError, "Don't know how to encode array of #{ary.first.class}"
    end
  end
end
