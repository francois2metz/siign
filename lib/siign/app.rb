require 'sinatra'
require 'tiime'

def login_tiime
  access_token = Siign::Authenticate.get_or_fetch_token(ENV['TIIME_USER'], ENV['TIIME_PASSWORD'])
  Tiime.bearer = access_token
  company = Tiime::Company.all.first
  Tiime.default_company_id = company.id
end

module Siign
  class App < Sinatra::Base
    before do
      login_tiime
    end

    get '/devis/:id' do
      quotation = Tiime::Quotation.find(id: params[:id])

      @title = quotation.title
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
      "Signature lancée"
    end
  end
end
