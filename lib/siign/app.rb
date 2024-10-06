# frozen_string_literal: true

require 'securerandom'
require 'sinatra'
require 'tiime'

module Siign
  # The web app to serve requests
  class App < Sinatra::Base
    enable :sessions
    set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }

    not_found do
      @title = 'Page non trouvée'

      erb :error404, layout: :default
    end

    get '/login' do
      @title = 'Connexion'

      erb :login, layout: :default
    end

    post '/login' do
      if ENV.fetch('TIIME_PASSWORD', nil) == params[:password]
        session[:logged] = true
        redirect to('/devis')
      else
        redirect to('/login')
      end
    end

    get '/devis' do
      return redirect('/login') unless logged?

      login_tiime

      @quotes = ::Tiime::Quotation.all
      @quotes_and_transactions = db.list_quotes_and_transactions
      @title = 'Devis'

      erb :quotes, layout: :default
    end

    get '/devis/:id/:transactionid' do
      transaction = docage.get_transaction(params[:transactionid])
      login_tiime
      quote = ::Tiime::Quotation.find(id: params[:id])

      @transaction_member_id = transaction.body['MemberSummaries'].first['Id']
      @title = quote.title

      erb :quote, layout: :base
    rescue Faraday::ResourceNotFound
      halt 404
    end

    post '/webhook' do
      halt 403 unless params['secret'] == ENV.fetch('WEBHOOK_SECRET', nil)

      request.body.rewind
      data = JSON.parse request.body.read
      docage.get_transaction(data['Id'])
      Notification.new.notify(Docage::DOCAGE_STATUS_TO_SYMBOL[data['Status']], data['Name'])
    rescue Faraday::ResourceNotFound
      halt 404
    end

    post '/devis/:id' do
      return redirect('/login') unless logged?

      login_tiime

      quote_id = params[:id]
      quote = ::Tiime::Quotation.find(id: quote_id)
      quote_pdf = ::Tiime::Quotation.pdf(id: quote_id)
      customer = ::Tiime::Customer.find(id: quote.client.id)
      contacts = ::Tiime::Contact.all(id: quote.client.id)

      transaction = docage.create_full_transaction(
        quote.title,
        StringIO.new(quote_pdf),
        docage_client_payload(customer, contacts),
        is_test: ENV.fetch('DOCAGE_TEST_MODE', 'false') != 'false',
        webhook: url("/webhook?secret=#{ENV.fetch('WEBHOOK_SECRET', nil)}")
      )

      db.associate_quote_and_transaction(quote_id, transaction.body['Id'])

      redirect to('/devis')
    end

    private

    def docage
      @docage ||= Docage.new(ENV.fetch('DOCAGE_USER', nil), ENV.fetch('DOCAGE_API_KEY', nil))
    end

    def db
      @db ||= Db.new(ENV.fetch('DB_PATH', nil))
    end

    def login_tiime
      access_token = Tiime.token(ENV.fetch('TIIME_USER', nil), ENV.fetch('TIIME_PASSWORD', nil))
      ::Tiime.bearer = access_token
      company = ::Tiime::Company.all.first
      ::Tiime.default_company_id = company.id
    end

    def logged?
      session[:logged] == true
    end

    def docage_client_payload(customer, contacts)
      {
        Email: customer.email,
        FirstName: contacts.first.firstname,
        LastName: contacts.first.lastname,
        Address1: customer.address,
        Address2: customer.address_complement,
        City: customer.city,
        ZipCode: customer.postal_code,
        Country: customer.country.name,
        Mobile: customer.phone
      }
    end
  end
end
