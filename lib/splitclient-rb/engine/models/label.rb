# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Models
      class Label
        ARCHIVED = 'archived'
        NO_RULE_MATCHED = 'default rule'
        EXCEPTION = 'exception'
        KILLED = 'killed'
        NOT_IN_SPLIT = 'not in split'
        NOT_READY = 'not ready'
        NOT_FOUND = 'definition not found'
      end
    end
  end
end
