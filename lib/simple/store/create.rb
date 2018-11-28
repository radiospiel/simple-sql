# require "active_support/core_ext/string/inflections"

module Simple::Store::Create
  Storage = Simple::Store::Storage

  extend self

  def create_model_during_save(model)
    created_model = create!(model.metamodel, [model.to_hash], on_conflict: nil).first
    model.send(:set_id_by_trusted_caller, created_model.id)
    created_model
  end

  def create!(metamodel, values, on_conflict:)
    models = build(metamodel, values)

    validate_on_create! models
    Simple::Store.validate! models

    records = Storage.convert_to_storage_representation(metamodel, models)
    Simple::SQL.insert(metamodel.table_name, records, into: Storage, on_conflict: on_conflict)
  end

  def build(metamodel, values)
    values.map do |value|
      metamodel.build({}).assign(value)
    end
  end

  private

  def validate_on_create!(models)
    return validate_on_create!([models]) unless models.is_a?(Array)

    models.each do |model|
      raise ArgumentError, "You cannot pass in an :id attribute" unless model.id.nil?
    end
  end
end
