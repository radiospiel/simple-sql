# private
module Simple::SQL::Encoder
  extend self
  extend Forwardable

  delegate connection: ::Simple::SQL

  def encode_args(args)
    args.map { |arg| encode_arg(arg) }
  end

  def encode_arg(arg)
    return arg unless arg.is_a?(Array)

    if arg.first.is_a?(String)
      "{#{arg.map { |a| "\"#{connection.escape(a)}\"" }.join(',')}}"
    else
      "{#{arg.join(',')}}"
    end
  end
end
