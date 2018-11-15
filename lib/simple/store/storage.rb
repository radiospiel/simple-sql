# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/BlockLength

module Simple::Store::Storage
  extend self

  Model = Simple::Store::Model

  def convert_one_to_storage_representation(metamodel, model)
    convert_to_storage_representation(metamodel, [model]).first
  end

  def convert_to_storage_representation(metamodel, models)
    attributes = metamodel.attributes
    dynamic_attributes = metamodel.attributes(kind: :dynamic)

    models.map do |model|
      record = model.to_hash.dup

      metadata = {}

      # move all attributes from record into metadata.
      record.reject! do |k, v|
        attribute = attributes[k]

        case attribute && attribute[:kind]
        when :static
          false
        when :dynamic
          metadata[k] = v
          true
        when nil
          # this is not a defined attribute (but maybe something internal, like "id" or "type")
          true
        else
          expect! attribute => { kind: [:static, :dynamic, :virtual] }
          true
        end
      end

      unless metadata.empty?
        unless dynamic_attributes.empty?
          raise "metadata on table without metadata column #{metadata.keys}"
        end
        record["metadata"] = metadata
      end
      record.delete "type" unless metamodel.column?("type")
      record.delete "id"
      record
    end
  end

  #
  Immutable = ::Simple::SQL::Helpers::Immutable

  def new_from_row(hsh, fq_table_name:)
    metamodel = determine_metamodel type: hsh[:type], fq_table_name: fq_table_name
    if metamodel
      Model.new(metamodel, trusted_data: hsh)
    elsif hsh.count == 1
      hsh.values.first
    else
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
