# frozen_string_literal: true

require 'securerandom'
require 'sinatra'
require 'tiime'

module Siign
  class App < Sinatra::Base
    enable :sessions
    set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }

    get '/login' do
      @title = 'Login'

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

      @quotes = Tiime::Quotation.all
      @quotes_and_transactions = db.list_quotes_and_transactions
      @title = 'Devis'

      erb :quotes, layout: :default
    end

    get '/devis/:id/:transactionid' do
      transaction = docage.get_transaction(params[:transactionid])
      login_tiime
      quote = Tiime::Quotation.find(id: params[:id])

      @transaction_id = transaction.body['MemberSummaries'].first['Id']
      @title = quote.title

      erb :quote, layout: :default
    rescue Faraday::ResourceNotFound
      halt 404
    end

    post '/devis/:id' do
      return redirect('/login') unless logged?

      login_tiime

      quote_id = params[:id]
      quote = Tiime::Quotation.find(id: quote_id)
      quote_pdf = Tiime::Quotation.pdf(id: quote_id)
      customer = Tiime::Customer.find(id: quote.client.id)
      contacts = Tiime::Contact.all(id: quote.client.id)

      transaction = docage.create_full_transaction(quote.title, StringIO.new(quote_pdf), {
                                                     Email: customer.email,
                                                     FirstName: contacts.first.firstname,
                                                     LastName: contacts.first.lastname,
                                                     Address1: customer.address,
                                                     Address2: customer.address_complement,
                                                     City: customer.city,
                                                     ZipCode: customer.postal_code,
                                                     Country: customer.country.name,
                                                     Mobile: customer.phone
                                                   })

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
      access_token = Authenticate.get_or_fetch_token(ENV.fetch('TIIME_USER', nil), ENV.fetch('TIIME_PASSWORD', nil))
      Tiime.bearer = access_token
      company = Tiime::Company.all.first
      Tiime.default_company_id = company.id
    end

    def logged?
      session[:logged] == true
    end
  end
end
