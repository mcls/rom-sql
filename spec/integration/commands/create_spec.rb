require 'spec_helper'
require 'virtus'

describe 'Commands / Create' do
  include_context 'database setup'

  subject(:users) { rom.commands.users }

  before do
    class Params
      include Virtus.model

      attribute :name

      def self.[](input)
        new(input)
      end
    end

    setup.commands(:users) do
      define(:create) do
        input Params
        result :one
      end

      define(:create_many, type: :create) do
        result :many
      end
    end

    setup.relation(:users)
  end

  context '#transaction' do
    it 'create record if nothing was raised' do
      result = users.create.transaction {
        users.create.call(name: 'Jane')
      }

      expect(result.value).to eq(id: 1, name: 'Jane')
    end

    it 'allows for nested transactions' do
      result = users.create.transaction {
        users.create.transaction {
          users.create.call(name: 'Jane')
        }
      }

      expect(result.value.value).to eq(id: 1, name: 'Jane')
    end

    it 'create nothing if anything was raised' do
      result = users.create.transaction(rollback: :always) {
        users.create.call(name: 'Jane')
      }

      expect(result.value).to be_nil
    end

    it 'create nothing if anything was raised in any nested transaction' do
      expect {
        expect {
          users.create.transaction {
            users.create.call(name: 'John')
            users.create.transaction {
              users.create.call(name: 'Jane')
              raise Exception
            }
          }
        }.to raise_error(Exception)
      }.to_not change { rom.relations.users.count }
    end
  end

  it 'returns a single tuple when result is set to :one' do
    result = users.try { users.create.call(name: 'Jane') }

    expect(result.value).to eql(id: 1, name: 'Jane')
  end

  it 'returns tuples when result is set to :many' do
    result = users.try do
      users.create_many.call([{ name: 'Jane' }, { name: 'Jack' }])
    end

    expect(result.value.to_a).to match_array([
      { id: 1, name: 'Jane' }, { id: 2, name: 'Jack' }
    ])
  end

  it 'handles not-null constraint violation error' do
    result = users.try { users.create.call(name: nil) }

    expect(result.error).to be_instance_of(ROM::SQL::ConstraintError)
    expect(result.error.message).to match(/not-null/)
  end

  it 'handles uniqueness constraint violation error' do
    result = users.try {
      users.create.call(name: 'Jane')
    } >-> user {
      users.try { users.create.call(name: user[:name]) }
    }

    expect(result.error).to be_instance_of(ROM::SQL::ConstraintError)
    expect(result.error.message).to match(/unique/)
  end
end
