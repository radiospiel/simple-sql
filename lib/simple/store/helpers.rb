# rubocop:disable Metrics/AbcSize

module Simple::Store::Helpers
  extend self

  Store = ::Simple::Store

  def return_results_if_complete!(metamodels, requested_ids, records)
    # we assume that no records will be passed in that haven't bee requested via
    # requested_ids.
    return records if records.count == requested_ids.count

    # If an id is listed twice in requested_ids the # of records will be
    # less than the # of requested ids. We check for this one - one should
    # never pass in duplicate ids.
    raise ArgumentError, "requested_ids should not have duplicates" if requested_ids.length != requested_ids.uniq.length

    found_ids   = records.map(&:id)
    missing_ids = requested_ids - found_ids

    raise Store::RecordNotFound.new(metamodels, missing_ids)
  end

  def table_name_for_metamodels(metamodels)
    unless metamodels.is_a?(Array)
      expect! metamodels => Store::Metamodel
      return metamodels.table_name
    end

    metamodels.each do |metamodel|
      expect! metamodel => Store::Metamodel
    end

    return metamodels.first.table_name if metamodels.length == 1

    metamodels = metamodels.uniq(&:table_name)
    return metamodels.first.table_name if metamodels.length == 1

    raise ArgumentError, "Duplicate tables requested: #{metamodels.map(&:table_name).uniq.inspect}"
  end
end
