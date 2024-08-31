require 'rspec'
require 'rack/test'

require 'siign'

RSpec.describe Siign::App do
  include Rack::Test::Methods

  def app
    described_class
  end
  let(:db_path) { '/tmp/test.sqlite' }

  before :each do
    FileUtils.rm db_path, force: true
    ENV['DB_PATH'] = db_path
  end

  describe 'GET /devis' do
    it 'display quotes' do
      expect(Siign::Authenticate).to receive(:get_or_fetch_token)
      expect(Tiime::Company).to receive(:all).and_return([Tiime::Company.new(id: 42)])
      expect(Tiime::Quotation).to receive(:all).and_return([
                                                             Tiime::Quotation.new(title: 'Test Quotation'),
                                                             Tiime::Quotation.new(title: 'New Quotation')
                                                           ])

      get '/devis'
      expect(last_response).to be_ok
      expect(last_response.body).to match('Test Quotation')
      expect(last_response.body).to match('New Quotation')
    end
  end

  describe 'GET /devis/:id/:transactionid' do
    it 'display a quote' do
      Siign::Db.new(db_path).associate_quote_and_transaction('2', 'iddocage')
      expect(Siign::Authenticate).to receive(:get_or_fetch_token)
      expect(Tiime::Company).to receive(:all).and_return([Tiime::Company.new(id: 42)])
      expect(Tiime::Quotation).to receive(:find).with(id: '2').and_return(Tiime::Quotation.new(title: 'Test Quotation'))
      expect_any_instance_of(Siign::Docage).to receive(:get_transaction).with('iddocage').and_return(double(body: { 'MemberSummaries' => [ { 'Id' => 'memberid' }]}))

      get '/devis/2/iddocage'
      expect(last_response).to be_ok
      expect(last_response.body).to match('Test Quotation')
    end

    it 'returns a 404 when the docage id doesnt exist' do
      expect(Siign::Authenticate).to receive(:get_or_fetch_token)
      expect(Tiime::Company).to receive(:all).and_return([Tiime::Company.new(id: 42)])
      expect(Tiime::Quotation).to receive(:find).with(id: '2').and_return(Tiime::Quotation.new(title: 'Test Quotation'))
      expect_any_instance_of(Siign::Docage).to receive(:get_transaction).with('iddocage').and_raise(Faraday::ResourceNotFound)

      get '/devis/2/iddocage'
      expect(last_response).to_not be_ok
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /devis/:id' do
    it 'create the docage transaction' do
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
      }).and_return(double(body: {'Id' => 'iddocage'}))
      post '/devis/3'

      expect(last_response.headers['location']).to eql('http://example.org/devis')
      expect(Siign::Db.new(db_path).get_transaction_by_quote_id('3')).to eql('iddocage')
    end
  end
end
