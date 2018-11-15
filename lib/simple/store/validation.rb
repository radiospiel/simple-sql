# require "active_support/core_ext/string/inflections"

module Simple::Store::Validation
  extend self

  # Validate the passed in models.
  def validate!(models)
    models.each do |model|
      model.metamodel.validate! model
    end
  end
end
