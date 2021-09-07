class Simple::SQL::Connection::Scope
  def all(into: :struct)
    connection.all(self, into: into)
  end

  def first(into: :struct)
    connection.ask(self, into: into)
  end

  def print(*args, io: STDOUT, width: :auto)
    connection.print(self, *args, io: io, width: width)
  end
end
