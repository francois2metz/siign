# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'

module Siign
  class Docage
    DOCAGE_STATUS_TO_SYMBOL = {
      0 => :draft,
      1 => :scheduled,
      2 => :waitinginformations,
      3 => :active,
      4 => :validated,
      5 => :signed,
      6 => :expired,
      7 => :refused,
      8 => :aborted
    }.freeze

    def initialize(username, api_key)
      @username = username
      @api_key = api_key
    end

    def create_full_transaction(name, fileio, client, is_test: false, webhook: nil)
      conn.post('/Transactions/CreateFullTransaction', transaction_payload(name, fileio, client, is_test: is_test, webhook: webhook))
    end

    def get_transaction(id)
      conn.get("/Transactions/ById/#{id}")
    end

    private

    def conn
      @conn ||= Faraday.new(url: 'https://api.docage.com') do |f|
        f.request :multipart
        f.response :raise_error
        f.response :json
        f.adapter :net_http
        f.request :authorization, :basic, @username, @api_key
      end
    end

    def transaction_payload(name, fileio, client, is_test:, webhook:)
      {
        Transaction: JSON.generate({
          Name: name,
          IsTest: is_test,
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
          ]
        }.tap { |t| t[:Webhook] = webhook unless webhook.nil? }),
        Client: JSON.generate(client),
        Devis: Faraday::Multipart::FilePart.new(fileio, 'application/pdf')
      }
    end
  end
end
