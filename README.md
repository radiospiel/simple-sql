# simple-sql

The simple-sql gem defines a module `Simple::SQL`, which you can use to execute SQL statements on a Postgresql database. Care has been taken to provide the simplest interface we could come up with.

However, apart from providing a simple interface `simple-sql` also provides a huge performance boon over `ActiveRecord` when interacting with your database, by cutting out all the `ActiveRecord` layers between the `pg` gem and you ruby code. However, `simple-sql` is still using ActiveRecord to manage connections.

**Note:** Databases other than Postgresql are not supported, and there are no plans to do so.

<!-- TOC -->

## Installation

The gem is available on rubygems as `simple-sql`.

Also make sure to add the `pg` gem to your Gemfile. `simple-sql` should be pretty flexible about the `pg` version: the earliest supported version is `0.21`. 

To use it add the following lines to your `Gemfile` and bundle up usual:

```ruby
gem 'simple-sql' # + version
gem 'pg' # + version
```

## Connecting to a database

Before you can send SQL commands to a database you need to connect first. `simple-sql` gives you the following options:

### Explicitly connect to the database

In a standalone applications you need to connect to a Postgresql server. `simple-sql` uses ActiveRecord's connection handling.

You can explicitly connect to a server by calling

```ruby
db = ::Simple::SQL.connect! "postgres://user:password@server[:port]/database"
```

You can then use `db.ask`, `db.all`, etc. (See below)

### Automatically determine connection details

Alternatively, you can have `simple-sql` figure out the details automatically:

```ruby
db = ::Simple::SQL.connect!
```

In that case we try to find connection parameters in the following places:

- the `DATABASE_URL` environment value
- the `config/database.yml` file from the current directory, taking `RAILS_ENV`/`RACK_ENV` into account.

### Using the default connection

You don't need to call `::Simple::SQL.connect!` inside a Rails application. `simple-sql` automatically uses the default connection when using `Simple::SQL` instead of an explicit database handle; i.e. typically you can use

```ruby
Simple::SQL.ask "SELECT ..."
```

and `simple-sql` will be doing the right thing. 

This is especially true in a Rails' applications controller action, because it allows you to mix Simple::SQL and ActiveRecord interactions with the database.

## Simple queries

### Simple::SQL.all: Fetching all results of a query

`Simple::SQL.all` runs a query, with optional arguments, and returns the result. Usage example:

```ruby
# returns an array of arrays `[ <id>, <email> ]`.
Simple::SQL.all "SELECT id, email FROM users WHERE id = ANY($1)", [1,2,3]
```

If a block is passed to SQL.all, each row is yielded into the block:

```ruby
Simple::SQL.all "SELECT id, email FROM users" do |id, email|
  # do something
end
```

Typically the SQL query returns an array of arrays (1 per row). If, however, the query is set up to only return a single column, this method returns an array of these values instead. This is especially useful with the block version:

Examples:

```ruby
Simple::SQL.all("SELECT id FROM users")        # returns an array of id values, but

Simple::SQL.all "SELECT id FROM users" do |id|
  # do something with the users' ids.
end
```

### Simple::SQL.each: run a block with each result of a query

This is identical to `.all`. It might offer beneficial optimisations, but this is theoretical at this point.

```ruby
Simple::SQL.each "SELECT id, email FROM users" do |id, email|
  # do something
end
```

### Simple::SQL.print: Printing results of a query

```ruby
Simple::SQL.print "SELECT id, email FROM users" do |id, email|
  # do something
end
```

### Simple::SQL.ask:  getting the first result

`Simple::SQL.ask` runs a query, with optional arguments, and returns the first result row or nil, if there was no result.

```ruby
Simple::SQL.ask "SELECT id, email FROM users WHERE id = ANY($1) LIMIT 1", [1,2,3]
```

If the SQL query only returns a single column, this method returns the column value of the first row; otherwise it returns an array (or `nil` if there was no result).

Usually all attributes are converted to its corresponding ruby type.

Examples:

```ruby
Simple::SQL.ask "SELECT id FROM users WHERE email=$1", "foo@local"         # returns a number (or `nil`) and
Simple::SQL.ask "SELECT id, email FROM users WHERE email=$?", "foo@local"  # returns an array `[ <id>, <email> ]` (or `nil`)
```

### Using placeholders

Note: whenever you run a query `simple-sql` takes care of sending query parameters over the wire properly. That means that you use placeholders `$1`, `$2`, etc. to use these inside your queries; the following is a correct example:

```ruby
Simple::SQL.all "SELECT * FROM users WHERE email=$1", "foo@bar.local"
```

Usually arguments are converted correctly when sending over to the database. One notable exception is sending `jsonb` data - you must use JSON.encode on the argument:

```ruby
Simple::SQL.ask "INSERT INTO table (column) VALUES($1)", JSON.encode(..)
```

It is probably worth pointing out that you cannotto use an array as the argument for the `IN(?)` SQL construct. Instead you want to use `ANY`, for example:

```ruby
Simple::SQL.all "SELECT * FROM users WHERE id = ANY($1)", [1,2,3]
```

### Determining the result type

By default `ask` and `all` convert each result row into an Array. Sometimes you might want to use Hashes or similar objects instead. To do so, you use the `into:` keyword argument:

```ruby
# returns a single Hash (or nil)
Simple::SQL.ask("SELECT id FROM users", into: Hash) 
```

If you want the returned record to be in a structure which is not a Hash, you can use the `into: <klass>` option. The following would return an array of up to two `OpenStruct` objects:

```ruby
sql = "SELECT id, email FROM users WHERE id = ANY($1) LIMIT 1", 
Simple::SQL.all sql, [1,2,3], into: OpenStruct
```

This supports all target types that take a constructor accepting Hash arguments.

It also supports a `:struct` argument, in which case simple-sql creates uses a Struct-class. Struct classes are reused when possible, and are maintained by `Simple::SQL`. This is potentially the best performing option when you want to use dot-notation.

```ruby
sql = "SELECT id, email FROM users WHERE id = ANY($1) LIMIT 1", 
Simple::SQL.all sql, [1,2,3], into: :struct
```

### Running non-`SELECT` queries

You can use `all` and `ask` with other queries as well. However, both only support running a single query. If you want to run multiple queries (i.e. a SQL script) you would probably look into `Simple::SQL.exec` instead.

Be aware that `Simple::SQL.exec` does not support placeholders: you cannot pass in arguments into `Simple::SQL.exec`.

### Transaction support

`simple-sql` borrows transaction support from `ActiveRecord`.

## Using scopes

A scope lets you build a condition over time, like this:

```ruby
scope = db.scope "SELECT * FROM users"
scope = scope.where(email: ["foo@foobar.test", "bar@foobar.test"])
scope = scope.where("deleted_at is NULL")
users = scope.all
```

This also works with the default connection, via `scope = Simple::SQL.scope ...`.

A scope supports the following methods to set up a scope:

|                           |                                             |
|---------------------------|---------------------------------------------|
| `where(args...)`          | add additional conditions. `where` also has additional support for using `?` instead of `$nn`, and supports JSONB query conditions. See [where.rb](lib/simple/sql/connection/scope/where.rb) for details.|
| `order_by(sql_fragment)`  ||
| `limit(limit)`            ||
| `offset(offset)`          ||
| `paginate(per:, page:)`   | adds pagination (calls `limit` and `offset`) |


These methods can then be used to evaluate the scope:

|                           |                                             |
|---------------------------|---------------------------------------------|
| `all(into: ...)`          | returns all matching entries |
| `first(into: ...)`        | returns the first matching entry|
| `count`                   | returns the exact count of matching records|
| `count_estimate`          | returns a fast estimate of the count of matching records. Note that this needs suitable and up-to-date indices.|
| `enumerate_groups(sql)`   | returns all groups |
| `count_by(sql)`           | counts by groups |
| `print`                   | print all matching entries|
| `explain`                 | returns the query plan|

## Inserting objects

Inserting objects is much faster via `simple-sql`. You should be able to insert ~1000 or so records per second into a table with no trouble.

```ruby
Simple::SQL.insert :users, first_name: "foo", last_name: "bar"
```

```ruby
users = []
users.push first_name: "first", last_name: "user"
users.push first_name: "second", last_name: "user"

Simple::SQL.insert :users, users
```

The `.insert` method lets you set up conflict resolution, via 

```ruby
Simple::SQL.insert :users, users, on_conflict: :ignore
```

## Advisory Locks

```ruby
Simple::SQL.transaction do
  Simple::SQL.lock!(4711)

  # do something.
end
```

## Logging

`simple-sql` builds a logger which logs all queries. The logger, by default, is created to write to STDERR; to get another logger use code like

```ruby
Simple::SQL.logger = Rails.logger
```

## Bugs and Limitations

**Limited support for types:** This gem does not use `pg`'s support for encoding and decoding types, since that might probably interfere with how ActiveRecord is setting up the `pg` gem.

It therefore assumes ActiveRecord is used in the same project, which sets up pg to not decode data in any meaningful way, and provides some code to decode the data returned from the database. Only a handful of types is currently supported by the Decoder - it is fairly easy to add new types, though.

## Test

1. `createdb simple-sql-test`
2. `bundle install`
3. `cp config/database.yml.sample config/database.yml`
4. `bundle exec rspec`
