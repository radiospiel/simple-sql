module Simple::Store
  class InvalidArguments < ArgumentError
    def initialize(errors)
      @errors = errors
      super()
    end

    attr_reader :errors

    def message
      errors
        .map { |key, error| "#{key}: #{error.map { |e| e.is_a?(String) ? e : e.inspect }.join(', ')}" }
        .join(", ")
    end
  end

  class RecordNotFound < RuntimeError
    def initialize(metamodels, missing_ids)
      @metamodels  = Array(metamodels)
      @missing_ids = missing_ids
      super()
    end

    attr_reader :metamodels
    attr_reader :missing_ids

    def message
      types = metamodels.map(&:name).join(", ")

      if missing_ids.length > 1
        "#{types}: cannot find records with ids #{missing_ids.join(', ')}"
      else
        "#{types}: cannot find record with id #{missing_ids.first}"
      end
    end
  end
end
