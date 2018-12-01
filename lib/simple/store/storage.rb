module Simple::Store::Storage
  extend self

  Model = Simple::Store::Model

  METAMODEL_TYPE_BY_PG_DATA_TYPE = {
    "character varying"            => :string,
    "timestamp without time zone"  => :timestamp,
    "USER-DEFINED"                 => :string # enums
  }

  READONLY_ATTRIBUTES = %(created_at updated_at id type)

  def register_static_attributes(metamodel, fq_table_name:)
    column_info = Simple::SQL::Reflection.column_info(fq_table_name)
    raise ArgumentError, "No such table #{fq_table_name.inspect}" if column_info.empty?

    column_info.each do |name, ostruct|
      next if name == "meta_data"

      data_type = ostruct.data_type
      type = (METAMODEL_TYPE_BY_PG_DATA_TYPE[data_type] || data_type.to_sym)

      metamodel.attribute name, type, writable: !READONLY_ATTRIBUTES.include?(name),
                                      readable: true,
                                      kind:     :static
    end
  end

  def convert_one_to_storage_representation(metamodel, model)
    # Extract and merge static and dynamic attributes
    record   = extract_static_attributes(metamodel, model)
    meta_data = extract_dynamic_attributes(metamodel, model)
    unless meta_data.empty?
      record["meta_data"] = meta_data
    end

    # Remove type attribute if this table doesn't have a type column
    # (but is statically typed instead.)
    record.delete "type" unless metamodel.attribute?("type")
    record
  end

  def convert_to_storage_representation(metamodel, models)
    models.map do |model|
      convert_one_to_storage_representation metamodel, model
    end
  end

  private

  def extract_static_attributes(metamodel, model)
    # copy all attributes from the model's internal Hash representation into
    # either the dynamic_attributes or the record Hash.
    metamodel.attributes(kind: :static).each_with_object({}) do |(k, _attribute), hsh|
      next if k == "id"
      next unless model.to_hash.key?(k)

      hsh[k] = model.to_hash[k]
    end
  end

  def extract_dynamic_attributes(metamodel, model)
    metamodel.attributes(kind: :dynamic).each_with_object({}) do |(k, _attribute), hsh|
      next unless model.to_hash.key?(k)
      hsh[k] = model.to_hash[k]
    end
  end

  public

  Immutable   = ::Simple::SQL::Helpers::Immutable
  Reflection  = ::Simple::SQL::Reflection

  def from_complete_row(hsh, fq_table_name:)
    meta_data = hsh.delete :meta_data
    if meta_data
      hsh = meta_data.merge(hsh)
    end

    # Note that we have to look up the metamodel for each row, since they can differ between
    # rows.
    metamodel = determine_metamodel(type: hsh[:type], fq_table_name: fq_table_name)
    if metamodel
      model = Model.new(metamodel, trusted_data: hsh)
    else
      STDERR.puts "Cannot find metamodel declaration for type #{hsh[:type].inspect} in table #{fq_table_name.inspect}"
      Immutable.create(hsh)
    end
  end

  private

  Registry = Simple::Store::Metamodel::Registry

  def determine_metamodel(type:, fq_table_name:)
    metamodels_by_table_name = Registry.grouped_by_table_name[fq_table_name]
    return nil if metamodels_by_table_name.nil?

    unless type
      metamodels = metamodels_by_table_name.values
      return metamodels.first if metamodels.length == 1
      raise "No metamodels defined in table #{fq_table_name}" if metamodels.empty?
      raise "Multiple metamodels defined in table #{fq_table_name}, but missing type"
    end

    metamodels_by_table_name[type] ||
      raise("No metamodel definition #{type.inspect} in table #{fq_table_name}")
  end
end
