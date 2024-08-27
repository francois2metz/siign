require 'rspec'
require 'rack/test'

require 'siign/app'

RSpec.describe Siign::App do
  include Rack::Test::Methods

  def app
    described_class
  end

  it 'display a quote' do
    expect(Siign::Authenticate).to receive(:get_or_fetch_token)
    expect(Tiime::Company).to receive(:all).and_return([Tiime::Company.new(id: 42)])
    expect(Tiime::Quotation).to receive(:find).with(id: '2').and_return(Tiime::Quotation.new(title: 'Test Quotation'))

    get '/devis/2'
    expect(last_response).to be_ok
    expect(last_response.body).to match('Test Quotation')
  end

  it 'display the pdf of the quote' do
    expect(Siign::Authenticate).to receive(:get_or_fetch_token)
    expect(Tiime::Company).to receive(:all).and_return([Tiime::Company.new(id: 42)])
    expect(Tiime::Quotation).to receive(:pdf).with(id: '2').and_return('pdftext')

    get '/devis/2/pdf'
    expect(last_response).to be_ok
    expect(last_response.headers).to include({ 'content-type' => 'application/pdf' })
    expect(last_response.body).to match('pdftext')
  end

  it 'start the transaction' do
    expect(Siign::Authenticate).to receive(:get_or_fetch_token)
    expect(Tiime::Company).to receive(:all).and_return([Tiime::Company.new(id: 42)])
    expect(Tiime::Quotation).to receive(:find).with(id: '3').and_return(Tiime::Quotation.new(title: 'Test Quotation', client: Tiime::Quotation.new({ id: 1 })))
    expect(Tiime::Quotation).to receive(:pdf).with(id: '3').and_return('pdftext')
    expect(Tiime::Customer).to receive(:find).with(id: 1).and_return(Tiime::Customer.new({ id: 1, email: 'francois@example.net', address: '2 avenue de l\'observatoire', address_complement: nil, city: 'Paris', postal_code: '75000', country: Tiime::Customer.new(name: 'France'), phone: '+33600000000' }))
    expect(Tiime::Contact).to receive(:all).with(id: 1).and_return([Tiime::Contact.new({ firstname: 'François', lastname: 'de Metz' })])

    expect_any_instance_of(Siign::Docage).to receive(:create_full_transaction).with('Test Quotation', instance_of(StringIO), {
        Email: 'francois@example.net',
        FirstName: 'François',
        LastName: 'de Metz',
        Address1: '2 avenue de l\'observatoire',
        Address2: nil,
        City: 'Paris',
        ZipCode: '75000',
        Country: 'France',
        Mobile: '+33600000000',
    })
    post '/devis/3'

    expect(last_response).to be_ok
    expect(last_response.body).to match('Signature lancée')
  end
end
