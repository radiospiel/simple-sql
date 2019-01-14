# require "active_support/core_ext/string/inflections"

require_relative "./helpers"

module Simple::Store::Delete
  extend self

  Store = ::Simple::Store
  H     = ::Simple::Store::Helpers
  Metamodel = ::Simple::Store::Metamodel

  def delete(args, force:)
    case args.length
    when 1
      models = args.first
      if models.is_a?(Array)
        delete1(models, force: force)
      else
        delete1([models], force: force).first
      end
    when 2
      metamodels, ids = *args
      metamodels = Metamodel.resolve metamodels
      metamodels = Array(metamodels)

      if ids.is_a?(Array)
        delete2(metamodels, ids, force: force)
      else
        delete2(metamodels, [ids], force: force).first
      end
    else
      raise ArgumentError, "Invalid # of arguments to Store.delete!"
    end
  end

  private

  def delete1(models, force:)
    # get all referenced metamodels. We need this to later pass it on
    # to delete2, which also verifies that they refer to only one table.
    metamodel_by_name = {}
    models.each do |model|
      metamodel_by_name[model.metamodel.name] ||= model.metamodel
    end
    metamodels = metamodel_by_name.values

    requested_ids = models.map(&:id)
    delete2 metamodels, requested_ids, force: force
  end

  def delete2(metamodels, requested_ids, force:)
    table_name = H.table_name_for_metamodels(metamodels)

    SQL.transaction do
      records = Store.all "DELETE FROM #{table_name} WHERE id = ANY ($1) RETURNING *", requested_ids
      H.return_results_if_complete! metamodels, requested_ids, records if force
      records
    end
  end
end
