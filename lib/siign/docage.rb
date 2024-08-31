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

    def get_transaction(id)
      conn.get("/Transactions/ById/#{id}")
    end

    private

    def transaction_payload(name, fileio, client)
      payload = {
        Transaction: JSON.generate({
          Name: name,
          TransactionFiles: [
            {
              Filename: 'devis.pdf',
              FriendlyName: 'Devis'
            }
          ],
          TransactionMembers: [
            {
              NotifyInvitation: false,
              NotifySignature: false,
              NotifyRefusal: false,
              NotifyCompletion: false,
              FriendlyName: 'Client'
            }
          ],
        }),
        Client: JSON.generate(client),
        Devis: Faraday::Multipart::FilePart.new(fileio, 'application/pdf')
      }

      payload
    end
  end
end
