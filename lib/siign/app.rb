require 'sinatra'
require 'tiime'

module Siign
  class App < Sinatra::Base
    before do
      login_tiime
    end

    get '/devis' do
      @quotes = Tiime::Quotation.all

      @title = 'Devis'
      erb :quotes, layout: :default
    end

    get '/devis/:id' do
      quote = Tiime::Quotation.find(id: params[:id])

      @title = quote.title
      @id = params[:id]
      erb :quote, layout: :default
    end

    get '/devis/:id/pdf' do
      content_type 'application/pdf'

      Tiime::Quotation.pdf(id: params[:id])
    end

    post '/devis/:id' do
      quote = Tiime::Quotation.find(id: params[:id])
      quote_pdf = Tiime::Quotation.pdf(id: params[:id])
      customer = Tiime::Customer.find(id: quote.client.id)
      contacts = Tiime::Contact.all(id: quote.client.id)

      docage = Siign::Docage.new(ENV['DOCAGE_USER'], ENV['DOCAGE_API_KEY'])

      docage.create_full_transaction(quote.title, StringIO.new(quote_pdf), {
        Email: customer.email,
        FirstName: contacts.first.firstname,
        LastName: contacts.first.lastname,
        Address1: customer.address,
        Address2: customer.address_complement,
        City: customer.city,
        ZipCode: customer.postal_code,
        Country: customer.country.name,
        Mobile: customer.phone,
      })
      @title = 'Procédure de signature lancée'
      erb :transaction_started, layout: :default
    end

    private

    def login_tiime
      access_token = Siign::Authenticate.get_or_fetch_token(ENV['TIIME_USER'], ENV['TIIME_PASSWORD'])
      Tiime.bearer = access_token
      company = Tiime::Company.all.first
      Tiime.default_company_id = company.id
    end
  end
end
