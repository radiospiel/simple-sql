## The Simple::Store interface

The Simple::Store modules provides code to create, save, update, or delete objects of a given type. This module also manages a type registry, which is used to find out about various aspects of a type, for example which attributes are defined and whether or not these are dynamic or static attributes.

Creating and saving objects also applies validation at the right time.

```ruby
class Simple::Store
  # build one or more, verify, and save.

  def self.create!(type, hsh_or_hshes)
  end

  # verify, and save one or more.

  def self.save!(obj_or_objs)
  end

  # update, verify, and save.

  def self.update!(type, id_or_ids, hsh)
  end

  def self.update!(obj_or_objs, hsh)
  end

  # delete one or more

  def self.delete!(obj_or_objs)
  end

  def self.delete!(typename_or_typenames, id_or_ids)
    # note: all type_or_types must refer to the same table.
  end
end
```

## Registering a type

The following code registers a type.

A type registration defines attributes. Depending on the readability and writability settings of an attribute this code defines getter and setter methods. If an attribute is read or write protected these methods check that the current user can call the method.

- static attributes are stored inside a table column.
- dynamic attributes are stored inside the "meta_data" JSONB column.
- virtual attributes are never stored; also, they are never writable.
- all attributes are readable by default; all non-virtual attributes are writable by default

When using the getters and setters no typecasting occurs.  

```ruby
metamodel = Simple::Store.register_type "Klass::Name", 
                    table_name: "postgres_table_name", 
                    superclass: SuperKlass do

  # Note: the type of a static attribute can be inferred from the database table
  static_attribute :static_name, type: :integer, writable: false
  
  dynamic_attribute :dynamic_name, type: :integer, writable: :protected
  virtual_attribute :virtual_name, type: :integer
end

metamodel.name                      # => "Klass::Name"
metamodel.table_name                # => "postgres_table_name"
metamodel.is_a?(Class)              # => true
metamodel.superclass == SuperKlass  # => true
```

One can also auto-detect a type from the database. This infers attributes from the actual database table.

```ruby
Simple::Store.register_type "Klass::Name", table_name: "postgres_table_name"
```

The generated class behaves as if it was implemented with an interface like this: 

```ruby
class Klass::Name < SuperKlass
  # Adds in create!, update!, save!, etc.
  # 
  include Simple::Store::MetamodelMethods

  def static_name
    @data[:static_name]
  end

  def dynamic_name
    @data[:dynamic_name]
  end

  def dynamic_name=(value)
    Simple::Store.current_session.check_protection! self.class, :dynamic_name, :write
    @data[:dynamic_name] = value
  end
end
```

Virtual attributes must be implemented explicitely. This can be done in a base
klass implementation:

```ruby
class Base::Organization
  def self.table_name
    "organizations"
  end
   
  def users_count
    sql = "SELECT COUNT(*) FROM user_organizations WHERE organization_id=$1"
    SQL.ask sql, $1
  end
end
```

```ruby
Simple::Store.register_type "Mpx::Organization", superclass: ::Base::Organization do

  virtual_attribute :users_count, type: :integer
end

metamodel.name                      # => "Klass::Name"
metamodel.table_name                # => "postgres_table_name"
metamodel.is_a?(Class)              # => true
metamodel.superclass == SuperKlass  # => true
```


### Mass assigning and type casting

One can assign multiple attributes in one go. This is done via

    Type.mass_assign!(obj, hsh)

When mass assigning String input values (and only String input values)
are converted into the specific type for the attribute. If the conversion
is not possible this will raise an ArgumentError.

This is used to

- a) quickly build objects from HTTP request parameters, and
- b) to convert data from JSON storage into our model representation.

This is also the only place where mass assignment takes place.

## Using a Metamodel klass

Classes registered via `Simple::Store.register_type` can be looked up in the Metamodel
registry (or, of course, via their name), and then used to build and manage
objects of that class.

```ruby
metamodel = Simple::Store.register_type 'Foo::Bar', ...
metamodel = Simple::Store.lookup_type 'Foo::Bar', ...

# Building objects
attrs = { .. }
obj = metamodel.build(attrs)        # => returns a object of type metamodel
obj.save!

# shortcut to validate & save the object
metamodel.create!(attrs)            # => returns the saved object of type metamodel

# update & save the object
obj = { .. }                        # => update attributes
obj.validate!
obj.save!
obj.update!(hsh)                    # => update attributes, validate and save

# Load objects

  "SELECT * FROM table", into: Simple::Store::Metamodel

# loads data from the table;
# looks up types in Simple::Store.registry
  # builds objects as requested, 
  # returns these objects
```


