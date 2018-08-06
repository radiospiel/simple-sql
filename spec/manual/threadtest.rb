#
# Run this script with `ruby spec/manual/threadtest.rb`
#
# The last output must be "number_of_connections: 1"
#

$: << "lib"
require "simple/sql"

Simple::SQL.connect!

def print_number_of_connections
  n = Simple::SQL.ask "SELECT sum(numbackends) FROM pg_stat_database"
  puts "number_of_connections: #{n}"
end

threads = []
100.times do
  threads << Thread.new do
    begin
      Simple::SQL.connect!
      p Simple::SQL.ask "SELECT 1"
      print_number_of_connections
    ensure
      Simple::SQL.disconnect!
    end
  end
end

threads.each(&:join)
sleep 0.1

p Simple::SQL.ask "SELECT 1"
print_number_of_connections
