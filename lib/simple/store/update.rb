# require "active_support/core_ext/string/inflections"

module Simple::Store::Update
  Storage = Simple::Store::Storage
  Store = Simple::Store

  extend self

  def update_model(model)
    expect! model.new_record? => false

    metamodel = model.metamodel
    record = Storage.convert_one_to_storage_representation(metamodel, model)

    keys = record.keys
    values = record.values_at(*keys)

    keys_w_placeholders = keys.each_with_index.map do |key, idx|
      "#{key}=$#{idx + 2}"
    end

    sql = "UPDATE #{metamodel.table_name} SET #{keys_w_placeholders.join(', ')} WHERE id=$1 RETURNING *"
    Store.ask sql, model.id, *values
  end
end
