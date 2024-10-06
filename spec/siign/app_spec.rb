# frozen_string_literal: true

require 'rspec'
require 'rack/test'

require 'siign'

RSpec.describe Siign::App do
  include Rack::Test::Methods

  def app
    described_class
  end
  let(:db_path) { '/tmp/test.sqlite' }
  let(:tiime_password) { 'test' }

  before do
    FileUtils.rm db_path, force: true
    ENV['DB_PATH'] = db_path
    ENV['TIIME_PASSWORD'] = tiime_password
  end

  def expect_tiime_login
    expect(Siign::Authenticate).to receive(:get_or_fetch_token)
    expect(Tiime::Company).to receive(:all).and_return([Tiime::Company.new(id: 42)])
  end

  describe 'GET /' do
    it 'returns a 404' do
      get '/'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(404)
    end
  end

  describe 'GET /login' do
    it 'display the login form' do
      get '/login'
      expect(last_response).to be_ok
    end
  end

  describe 'POST /login' do
    it 'check the password and redirect to /devis' do
      post '/login', password: tiime_password

      expect(last_response.status).to eq(302)
      expect(last_response.headers['location']).to eq('http://example.org/devis')
    end

    it 'display the login form if the password is wrong' do
      post '/login', password: 'test2'

      expect(last_response.status).to eq(302)
      expect(last_response.headers['location']).to eq('http://example.org/login')
    end
  end

  describe 'GET /devis' do
    it 'display quotes when connected' do
      post '/login', password: tiime_password
      expect_tiime_login
      expect(Tiime::Quotation).to receive(:all).and_return([
                                                             Tiime::Quotation.new(title: 'Test Quotation'),
                                                             Tiime::Quotation.new(title: 'New Quotation')
                                                           ])

      get '/devis'
      expect(last_response).to be_ok
      expect(last_response.body).to match('Test Quotation')
      expect(last_response.body).to match('New Quotation')
    end

    it 'display nothing if not connected' do
      get '/devis'

      expect(last_response.status).to eq(302)
      expect(last_response.headers['location']).to eq('http://example.org/login')
    end
  end

  describe 'GET /devis/:id/:transactionid' do
    it 'display a quote' do
      Siign::Db.new(db_path).associate_quote_and_transaction('2', 'iddocage')
      expect_tiime_login
      expect(Tiime::Quotation).to receive(:find).with(id: '2').and_return(Tiime::Quotation.new(title: 'Test Quotation'))
      expect_any_instance_of(Siign::Docage).to receive(:get_transaction).with('iddocage').and_return(double(body: { 'MemberSummaries' => [{ 'Id' => 'memberid' }] }))

      get '/devis/2/iddocage'
      expect(last_response).to be_ok
      expect(last_response.body).to match('Test Quotation')
    end

    it 'returns a 404 when the docage id doesnt exist' do
      expect_any_instance_of(Siign::Docage).to receive(:get_transaction).with('iddocage').and_raise(Faraday::ResourceNotFound)

      get '/devis/2/iddocage'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /webhook' do
    it 'receive the webhook and send the success notification' do
      Siign::Db.new(db_path).associate_quote_and_transaction('2', 'iddocage')
      expect_any_instance_of(Siign::Docage).to receive(:get_transaction).with('iddocage').and_return(double(body: { 'MemberSummaries' => [{ 'Id' => 'memberid' }] }))
      expect_any_instance_of(Siign::Notification).to receive(:notify).with(:signed, 'Test Quotation')

      post '/webhook', JSON.generate({ Id: 'iddocage', Status: 5, Name: 'Test Quotation' }), 'CONTENT_TYPE' => 'application/json'
      expect(last_response).to be_ok
    end

    it 'receive the webhook and send the refused notification' do
      Siign::Db.new(db_path).associate_quote_and_transaction('2', 'iddocage')
      expect_any_instance_of(Siign::Docage).to receive(:get_transaction).with('iddocage').and_return(double(body: { 'MemberSummaries' => [{ 'Id' => 'memberid' }] }))
      expect_any_instance_of(Siign::Notification).to receive(:notify).with(:refused, 'Test Quotation')

      post '/webhook', JSON.generate({ Id: 'iddocage', Status: 7, Name: 'Test Quotation' }), 'CONTENT_TYPE' => 'application/json'
      expect(last_response).to be_ok
    end

    it 'returns a 404 when the docage id doesnt exist' do
      expect_any_instance_of(Siign::Docage).to receive(:get_transaction).with('iddocage').and_raise(Faraday::ResourceNotFound)

      post '/webhook', JSON.generate({ Id: 'iddocage', Status: 5, Name: 'Test Quotation' }), 'CONTENT_TYPE' => 'application/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /devis/:id' do
    it 'create the docage transaction when connected' do
      post '/login', password: tiime_password
      expect_tiime_login
      expect(Tiime::Quotation).to receive(:find).with(id: '3').and_return(Tiime::Quotation.new(title: 'Test Quotation',
                                                                                               client: Tiime::Quotation.new({ id: 1 })))
      expect(Tiime::Quotation).to receive(:pdf).with(id: '3').and_return('pdftext')
      expect(Tiime::Customer).to receive(:find).with(id: 1).and_return(Tiime::Customer.new({ id: 1,
                                                                                             email: 'francois@example.net', address: '2 avenue de l\'observatoire', address_complement: nil, city: 'Paris', postal_code: '75000', country: Tiime::Customer.new(name: 'France'), phone: '+33600000000' }))
      expect(Tiime::Contact).to receive(:all).with(id: 1).and_return([Tiime::Contact.new({ firstname: 'François',
                                                                                           lastname: 'de Metz' })])

      expect_any_instance_of(Siign::Docage).to receive(:create_full_transaction).with('Test Quotation', instance_of(StringIO), {
                                                                                        Email: 'francois@example.net',
                                                                                        FirstName: 'François',
                                                                                        LastName: 'de Metz',
                                                                                        Address1: '2 avenue de l\'observatoire',
                                                                                        Address2: nil,
                                                                                        City: 'Paris',
                                                                                        ZipCode: '75000',
                                                                                        Country: 'France',
                                                                                        Mobile: '+33600000000'
                                                                                      }, is_test: false, webhook: 'http://example.org/webhook').and_return(double(body: { 'Id' => 'iddocage' }))
      post '/devis/3'

      expect(last_response.headers['location']).to eq('http://example.org/devis')
      expect(Siign::Db.new(db_path).get_transaction_by_quote_id('3')).to eq('iddocage')
    end
  end
end
