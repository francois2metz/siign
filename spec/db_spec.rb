require 'rspec'

require 'siign'

RSpec.describe Siign::Db do
  describe '#associate_quote_and_transaction' do
    it 'insert the transaction id associated to a quote' do
      db = described_class.new(':memory:')
      db.associate_quote_and_transaction('1', '42')

      expect(db.get_transaction_by_quote_id('1')).to eql('42')
    end

    it 'insert the transaction id associated to a quote2' do
      db = described_class.new(':memory:')
      db.associate_quote_and_transaction('1', 'a160d65f-bb7e-4184-a7f9-da3da953ad7e')

      expect(db.get_transaction_by_quote_id('1')).to eql('a160d65f-bb7e-4184-a7f9-da3da953ad7e')
    end

    it 'cannot insert another transaction_id for the same quote' do
      db = described_class.new(':memory:')
      db.associate_quote_and_transaction('1', '42')
      expect {
        db.associate_quote_and_transaction('1', '42')
      }.to raise_error(SQLite3::ConstraintException)
    end
  end

  describe '#get_transaction_by_quote_id' do
    it 'returns nil if there is no transaction associated' do
      db = described_class.new(':memory:')
      expect(db.get_transaction_by_quote_id('1')).to be_nil
    end
  end

  describe '#list_quotes_and_transactions' do
    it 'returns an empty list' do
      db = described_class.new(':memory:')
      expect(db.list_quotes_and_transactions).to be_empty
    end

    it 'returns the list of quotes and transactions' do
      db = described_class.new(':memory:')
      db.associate_quote_and_transaction('1', '42')
      db.associate_quote_and_transaction('2', '43')
      expect(db.list_quotes_and_transactions).to eq([
                                                      ['1', '42'],
                                                      ['2', '43']
                                                    ])
    end
  end
end
