require 'faraday'
require 'faraday/multipart'

module Siign
  class Docage
    def initialize(username, api_key)
      @username = username
      @api_key = api_key
    end

    def conn
      @conn ||= Faraday.new(url: 'https://api.docage.com') do |f|
        f.request :multipart
        f.response :raise_error
        f.response :json
        f.adapter :net_http
        f.request :authorization, :basic, @username, @api_key
      end
    end

    def create_full_transaction(name, fileio, client)
      conn.post('/Transactions/CreateFullTransaction', transaction_payload(name, fileio, client))
    end

    private

    def transaction_payload(name, fileio, client)
      payload = {
        Transaction: JSON.generate({
          Name: name,
          TransactionFiles: [
            {
              Filename: 'devis-1.pdf',
              FriendlyName: 'Contrat'
            }
          ],
          TransactionMembers: [{ FriendlyName: 'Client' }],
        }),
        Client: JSON.generate(client),
        Contrat: Faraday::Multipart::FilePart.new(fileio, 'application/pdf')
      }

      payload
    end
  end
end
