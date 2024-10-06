# frozen_string_literal: true

require 'sqlite3'

module Siign
  # Access to the sqlite database
  class Db
    def initialize(db_path)
      @db_path = db_path
      init_db
    end

    def associate_quote_and_transaction(quote_id, transaction_id)
      db.execute('INSERT INTO quote_transaction (quote_id, transaction_id) VALUES (?, ?)', [quote_id, transaction_id])
    end

    def get_transaction_by_quote_id(quote_id)
      result = db.execute('SELECT transaction_id FROM quote_transaction where quote_id = ?', [quote_id])
      return nil if result.empty?

      result.first.first
    end

    def list_quotes_and_transactions
      db.execute('SELECT quote_id, transaction_id FROM quote_transaction')
    end

    private

    def db
      @db ||= SQLite3::Database.new @db_path
    end

    def init_db
      db.execute <<-SQL
        create table if not exists quote_transaction (
          quote_id varchar(36) PRIMARY KEY,
          transaction_id varchar(36)
        );
      SQL
    end
  end
end
