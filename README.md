# simple-sql

## Installation

The gem is available through our private gem host:

```ruby
gem 'simple-sql' # + version
```

## Usage

This gem defines a module `Simple::SQL`, which you can use to execute SQL statements
on the current ActiveRecord connection.

Simple::SQL takes care of converting arguments back and forth.

### Running a query

`Simple::SQL.all` runs a query, with optional arguments, and returns the result. Usage example:

    Simple::SQL.all "SELECT id, email FROM users WHERE id = ANY($1)", [1,2,3]

If the SQL query returns rows with one column, this method returns an array of these values.
Otherwise it returns an array of arrays.

Examples:

```ruby
Simple::SQL.all("SELECT id FROM users")        # returns an array of id values, but
Simple::SQL.all("SELECT id, email FROM users") # returns an array of arrays `[ <id>, <email> ]`.
```

If a block is passed to SQL.all, each row is yielded into the block:

```ruby
Simple::SQL.all "SELECT id, email FROM users" do |id, email|
  # do something
end
```

In this case SQL.all returns `self`, which lets you chain function calls. 

### Getting the first result

`Simple::SQL.ask` returns runs a query, with optional arguments, and returns the first result row.


    Simple::SQL.ask "SELECT id, email FROM users WHERE id = ANY($1) LIMIT 1", [1,2,3]

If the SQL query returns rows with one column, this method returns the column value of the first row; otherwise it returns an array (or `nil` if there was no result).

Examples:

```ruby
Simple::SQL.ask "SELECT id FROM users WHERE email=$1", "foo@local"         # returns a number (or `nil`) and
Simple::SQL.ask "SELECT id, email FROM users WHERE email=$?", "foo@local"  # returns an array `[ <id>, <email> ]` (or `nil`)
```

## Notes

Remember that Postgresql uses $1, $2, etc. as placeholders; the following is correct:

```ruby
Simple::SQL.all "SELECT * FROM users WHERE email=$1", "foo@bar.local"
```

Also note that `IN(?)` is not supported by the Postgresql client library; instead you
must use `= ANY`, for example:

```ruby
Simple::SQL.all "SELECT * FROM users WHERE id = ANY($1)", [1,2,3]
```


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
