require "simple-sql"

module Simple; end
module Simple::Store; end

require_relative "store/errors"
require_relative "store/model"
require_relative "store/metamodel"
require_relative "store/registry"
require_relative "store/storage"
require_relative "store/create"
require_relative "store/delete"
require_relative "store/find"
require_relative "store/validation"
require_relative "store/update"

# A simple document store
#
# The document store allows one to create, update, destroy records of specific
# types. In doing so validations are applied at the right times.
#
# A type has these attributes:
#
# - a table name.
# - a fixed list of attributes. A basic list is derived from the database layout.
# - a fixed list of associations. A basic list is derived from the database layout.
#
# Custom types provide their own list of attributes and associations. Both attributes
# and associations are registered with a name and a type.
#
# All attributes that do not exist as columns in the table are called "dynamic"
# attributes and read from a meta_data JSONB attribute. Type conversions are done to
# convert from and to types that are not supported by JSON (mostly dates and boolean.)
#
module Simple::Store
  extend self

  # Runs a query and returns the first result row of a query.
  #
  # Examples:
  #
  # - <tt>Simple::Store.ask "SELECT * FROM users WHERE email=$? LIMIT 1", "foo@local"</tt>
  def ask(*args, into: nil)
    into ||= Storage
    Simple::SQL.ask(*args, into: into)
  end

  # Runs a query and returns all resulting row of a query, as Simple::Store::Model objects.
  #
  # Examples:
  #
  # - <tt>Simple::Store.all "SELECT * FROM users WHERE email=$?", "foo@local"</tt>
  def all(*args, into: nil)
    into ||= Storage
    Simple::SQL.all(*args, into: into)
  end

  # build one or more objects, verify, and save.
  #
  # Parameters:
  #
  # - metamodel: the type [Metamodel, String]
  # - values: a Hash or an Array of Hashes
  #
  # Returns the newly created model or an array of newly created models.
  #
  # If validation fails for at least one of the objects no objects will be created.
  def create!(metamodel, values, on_conflict: nil)
    metamodel = Metamodel.resolve(metamodel)

    if values.is_a?(Array)
      Create.create!(metamodel, values, on_conflict: on_conflict)
    else
      Create.create!(metamodel, [values], on_conflict: on_conflict).first
    end
  end

  # build one or more objects
  #
  # Parameters:
  #
  # - metamodel: the type [Metamodel, String]
  # - values: a Hash or an Array of Hashes
  #
  # Returns the built model or an array of built models.
  def build(metamodel, values)
    metamodel = Metamodel.resolve(metamodel)

    if values.is_a?(Array)
      Create.build(metamodel, values)
    else
      Create.build(metamodel, [values]).first
    end
  end

  # Validate the passed in models.
  #
  # Raises an error if any model is invalid.
  def validate!(models)
    Validation.validate!(Array(models))
  end

  # Delete one or more models from the database.
  #
  # def delete!(models)
  # def delete!(metamodels, ids)
  #
  # Returns a copy of the deleted models
  def delete!(*args)
    Delete.delete args, force: true
  end

  # def delete(models)
  # def delete(metamodels, ids)
  def delete(*args)
    Delete.delete args, force: false
  end

  # -- finding ----------------------------------------------------------------

  # Reload a model fro the database
  def reload(model)
    raise ArgumentError, "Cannot reload a unsaved model (of type #{model.metamodel.name.inspect})" if model.new_record?

    find(model.metamodel, model.id)
  end

  # Find a nuber of models in the database
  #
  # Parameters:
  #
  # - metamodels: a Metamodel, String, or an Array of Metamodels and/or Strings
  # - ids: an ID value or an array of ids.
  #
  # Returns a array of newly built models.
  def find(metamodels, ids)
    expect! ids => [Array, Integer]

    metamodels = Metamodel.resolve(metamodels)

    if ids.is_a?(Integer)
      Simple::Store::Find.find!(metamodels, [ids]).first
    else
      Simple::Store::Find.find!(metamodels, ids)
    end
  end

  # verify, and save one or more models.
  def save!(models)
    return save!([models]).first unless models.is_a?(Array)

    validate! models

    models.map do |model|
      if model.new_record?
        Create.create_model_during_save(model)
      else
        Update.update_model(model)
      end
    end
  end
end
