require 'rom/sql/commands'
require 'rom/sql/commands/transaction'

module ROM
  module SQL
    module Commands
      class Update < ROM::Commands::Update
        include Transaction

        option :original, type: Hash, reader: true

        alias_method :to, :call

        def execute(tuple)
          attributes = input[tuple]
          validator.call(attributes)

          changed = diff(attributes.to_h)

          if changed.any?
            update(changed)
          else
            []
          end
        end

        def change(original)
          self.class.new(relation, options.merge(original: original))
        end

        def update(tuple)
          pks = relation.map { |t| t[relation.model.primary_key] }
          relation.update(tuple)
          relation.unfiltered.where(relation.model.primary_key => pks).to_a
        end

        private

        def diff(tuple)
          if original
            Hash[tuple.to_a - (tuple.to_a & original.to_a)]
          else
            tuple
          end
        end
      end
    end
  end
end
