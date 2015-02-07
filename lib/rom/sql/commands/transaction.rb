module ROM
  module SQL
    module Commands
      module Transaction
        ROM::SQL::Rollback = Class.new(Sequel::Rollback)

        def transaction(options = {}, &block)
          relation.dataset.db.transaction(options, &block)
        end
      end
    end
  end
end
