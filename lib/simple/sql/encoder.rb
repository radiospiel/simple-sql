# private
module Simple::SQL::Encoder
  extend self

  def encode_args(connection, args)
    args.map { |arg| encode_arg(connection, arg) }
  end

  def encode_arg(connection, arg)
    return arg unless arg.is_a?(Array)

    if arg.first.is_a?(String)
      "{#{arg.map { |a| "\"#{connection.escape(a)}\"" }.join(',')}}"
    else
      "{#{arg.join(',')}}"
    end
  end
end
