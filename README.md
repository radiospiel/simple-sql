# simple-sql

The simple-sql gem defines a module `Simple::SQL`, which you can use to execute
SQL statements on a Postgresql database. Care has been taken to provide the 
simplest interface we could come up with.

**Note:** Databases other than Postgresql are not supported, and there are no
plans to do so. If you deem that necessary, feel free to fork this code into a
`simple-sql-<yourdatabase>` gem to provide the same or a similar interface.

## Installation

The gem is available on rubygems as `simple-sql`. To use it add the following
line to your `Gemfile` and bundle us usual:

    gem 'simple-sql' # + version

## Usage

### Connecting to a database

Before you can send SQL commands to a database you need to connect first. `simple-sql`
gives you the following options:

1. **Use the current ActiveRecord connection:** when running inside a Rails application
   you typically have a connection to Postgresql configured already. In that case you
   don't need to do anything; `simple-sql` will just use the current database connection.
   
   This is usually the right thing, especially since `simple-sql`, when called from inside
   a controller action, is using the connection valid in the current context.

2. **Explicitely connect** on standalone applications you need to connect to a Postgresql
   server. **Note that in this case there are no pooled connections!** simple-sql is not
   thread-/fiber-safe in this mode.

   You can explictely connect to a server by calling

         ::Simple::SQL.connect! "postgres://user:password@server[:port]/database"

   Alternatively, you can have `simple-sql` figure out the details automatically:

         ::Simple::SQL.connect!

   In that case we try to find connection parameters in the following places:
   
   - the `DATABASE_URL` environment value
   - the `config/database.yml` file from the current directory, taking `RAILS_ENV`/`RACK_ENV` into account.

### Using placeholders

Note: whenever you run a query `simple-sql` takes care of sending query parameters over the wire properly. That means that you use placeholders `$1`, `$2`, etc. to use these inside your queries; the following is a correct example:

    Simple::SQL.all "SELECT * FROM users WHERE email=$1", "foo@bar.local"

Also note that it is not possible to use an array as the argument for the `IN(?)` SQL construct. Instead you want to use `ANY`, for example:

    Simple::SQL.all "SELECT * FROM users WHERE id = ANY($1)", [1,2,3]

### Simple::SQL.all: Fetching all results of a query

`Simple::SQL.all` runs a query, with optional arguments, and returns the result. Usage example:

    Simple::SQL.all "SELECT id, email FROM users WHERE id = ANY($1)", [1,2,3]

If the SQL query returns rows with one column, this method returns an array of these values.
Otherwise it returns an array of arrays.

Examples:

    Simple::SQL.all("SELECT id FROM users")        # returns an array of id values, but
    Simple::SQL.all("SELECT id, email FROM users") # returns an array of arrays `[ <id>, <email> ]`.

If a block is passed to SQL.all, each row is yielded into the block:

    Simple::SQL.all "SELECT id, email FROM users" do |id, email|
      # do something
    end

### Simple::SQL.ask:  getting the first result

`Simple::SQL.ask` runs a query, with optional arguments, and returns the first result row or nil, if there was no result.

    Simple::SQL.ask "SELECT id, email FROM users WHERE id = ANY($1) LIMIT 1", [1,2,3]

If the SQL query returns rows with one column, this method returns the column value of the first row; otherwise it returns an array (or `nil` if there was no result).

Examples:

    Simple::SQL.ask "SELECT id FROM users WHERE email=$1", "foo@local"         # returns a number (or `nil`) and
    Simple::SQL.ask "SELECT id, email FROM users WHERE email=$?", "foo@local"  # returns an array `[ <id>, <email> ]` (or `nil`)

### Simple::SQL.ask/Simple::SQL.all:  fetching hashes

While `ask` and `all` convert each result row into an Array, sometimes you might want
to use Hashes or similar objects instead. To do so, you use the `into:` keyword argument:

    # returns a single Hash (or nil)
    Simple::SQL.ask("SELECT id FROM users", into: Hash) 

If you want the returned record to be in a structure which is not a Hash, you can use
the `into: <klass>` option. The following would return an array of up to two `OpenStruct`
objects:

    sql = "SELECT id, email FROM users WHERE id = ANY($1) LIMIT 1"
    Simple::SQL.all sql, [1,2,3], into: OpenStruct

This supports all target types that take a constructor which accepts Hash arguments.

It also supports a :struct argument, in which case simple-sql creates uses a Struct-class.
Struct classes are reused when possible, and are maintained by Simple::SQL. 

    sql = "SELECT id, email FROM users WHERE id = ANY($1) LIMIT 1"
    Simple::SQL.all sql, [1,2,3], into: :struct

### Transaction support

`simple-sql` has limited support for nested transactions. When running with a ActiveRecord
connection, we use ActiveRecord's transaction implementation (which uses savepoints for nested
transactions, so you might be able to rollback from inside a nested transaction).

When connecting via `Simple::SQL.connect!` we do not support the same level of nesting support (yet). You can still nest transactions, but raising an error terminates *all* current transactions. 

## Logging

`simple-sql` builds a logger which logs all queries. The logger, by default, is
created to write to STDERR; to get another logger use code like

    Simple::SQL.logger = Rails.logger

## Bugs and Limitations

### 1. Multiple connections

It is currently not possible to run SQL queries against a database which is not
connected via ActiveRecord::Base.connection.

### 2. Postgresql only

Only Postgresql is supported.

### 3. Limited support for types

This gem does not use `pg`'s support for encoding and decoding types, since
that might probably interfere with how ActiveRecord is setting up the `pg`
gem.

It therefore assumes ActiveRecord is used in the same project, which sets up
pg to not decode data in any meaningful way, and provides some code to decode
the data returned from the database. Only a handful of types is currently
supported by the Decoder - it is fairly easy to add new types, though.

### 4. text arrays

The library used to parse array results seems to be buggy if the array contains
strings containing the "`" character.

## Test

1. `createdb simple-sql-test`
2. `bundle install`
3. `bin/rspec`

## Test again
