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
  let(:webhook_secret) { 'h4ck3r' }
  let(:docage) { instance_double(Siign::Docage) }
  let(:quote_notification) { instance_double(Siign::QuoteNotification) }

  before do
    FileUtils.rm db_path, force: true
    ENV['DB_PATH'] = db_path
    ENV['TIIME_PASSWORD'] = tiime_password
    ENV['WEBHOOK_SECRET'] = webhook_secret
  end

  def expect_tiime_login
    expect(Siign::Tiime).to receive(:token)
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

    it 'redirect if logged' do
      post '/login', password: tiime_password

      get '/login'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['location']).to eq('http://example.org/devis')
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
      expect(Siign::Docage).to receive(:new).and_return(docage)
      expect(docage).to receive(:get_transaction)
        .with('iddocage')
        .and_return(double(body: { 'MemberSummaries' => [{ 'Id' => 'memberid' }] }))

      get '/devis/2/iddocage'
      expect(last_response).to be_ok
      expect(last_response.body).to match('Test Quotation')
    end

    it 'returns a 404 when the docage id doesnt exist' do
      expect(Siign::Docage).to receive(:new).and_return(docage)
      expect(docage).to receive(:get_transaction).with('iddocage').and_raise(Faraday::ResourceNotFound)

      get '/devis/2/iddocage'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /webhook' do
    before do
      allow(Siign::Docage).to receive(:new).and_return(docage)
      allow(Siign::QuoteNotification).to receive(:new).and_return(quote_notification)
    end

    [
      {
        docage_status: 5,
        expected_quotation_status: 'accepted',
        expected_notification_status: :signed
      },
      {
        docage_status: 6,
        expected_quotation_status: 'cancelled',
        expected_notification_status: :expired
      },
      {
        docage_status: 7,
        expected_quotation_status: 'refused',
        expected_notification_status: :refused
      }, {
        docage_status: 8,
        expected_quotation_status: 'cancelled',
        expected_notification_status: :aborted
      }
    ].each do |test|
      docage_status = test[:docage_status]
      expected_quotation = test[:expected_quotation_status]
      expected_notification = test[:expected_notification_status]

      it "for status: #{docage_status}, update status: #{expected_quotation}, notification: #{expected_notification}" do
        Siign::Db.new(db_path).associate_quote_and_transaction('2', 'iddocage')
        expect(docage).to receive(:get_transaction)
          .with('iddocage')
          .and_return(double(body: { 'MemberSummaries' => [{ 'Id' => 'memberid' }] }))
        expect_tiime_login
        quotation = Tiime::Quotation.new(title: 'Test Quotation', status: 'saved')
        expect(Tiime::Quotation).to receive(:find).with(id: '2').and_return(quotation)
        expect(quotation).to receive(:update)
        expect(quote_notification).to receive(:notify).with(expected_notification, 'Test Quotation')

        post "/webhook?secret=#{webhook_secret}",
             JSON.generate({ Id: 'iddocage', Status: docage_status, Name: 'Test Quotation' }),
             'CONTENT_TYPE' => 'application/json'
        expect(last_response).to be_ok
        expect(quotation.status).to eql(expected_quotation)
      end
    end

    it 'receive the webhook and dont update the quote' do
      Siign::Db.new(db_path).associate_quote_and_transaction('2', 'iddocage')
      expect(docage).to receive(:get_transaction)
        .with('iddocage')
        .and_return(double(body: { 'MemberSummaries' => [{ 'Id' => 'memberid' }] }))
      expect_tiime_login
      quotation = Tiime::Quotation.new(title: 'Test Quotation', status: 'saved')
      expect(Tiime::Quotation).to receive(:find).with(id: '2').and_return(quotation)
      expect(quotation).not_to receive(:update)
      expect(quote_notification).to receive(:notify).with(:active, 'Test Quotation')

      post "/webhook?secret=#{webhook_secret}",
           JSON.generate({ Id: 'iddocage', Status: 3, Name: 'Test Quotation' }),
           'CONTENT_TYPE' => 'application/json'
      expect(last_response).to be_ok
    end

    it 'returns a 404 when the docage id doesnt exist' do
      expect(docage).to receive(:get_transaction).with('iddocage').and_raise(Faraday::ResourceNotFound)

      post "/webhook?secret=#{webhook_secret}",
           JSON.generate({ Id: 'iddocage', Status: 5, Name: 'Test Quotation' }),
           'CONTENT_TYPE' => 'application/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(404)
    end

    it 'returns a 403 when the secret doesnt matche' do
      post '/webhook?secret=bad',
           JSON.generate({ Id: 'iddocage', Status: 5, Name: 'Test Quotation' }),
           'CONTENT_TYPE' => 'application/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(403)
    end
  end

  describe 'POST /devis/:id' do
    it 'create the docage transaction when connected' do
      post '/login', password: tiime_password
      expect_tiime_login
      expect(Tiime::Quotation).to receive(:find)
        .with(id: '3')
        .and_return(Tiime::Quotation.new(title: 'Test Quotation',
                                         status: 'saved',
                                         client: Tiime::Quotation.new({ id: 1 })))
      expect(Tiime::Quotation).to receive(:pdf).with(id: '3').and_return('pdftext')
      expect(Tiime::Customer).to receive(:find)
        .with(id: 1)
        .and_return(Tiime::Customer.new({ id: 1,
                                          email: 'francois@example.net',
                                          address: '2 avenue de l\'observatoire',
                                          address_complement: nil,
                                          city: 'Paris',
                                          postal_code: '75000',
                                          country: Tiime::Customer.new(name: 'France'),
                                          phone: '+33600000000' }))
      expect(Tiime::Contact).to receive(:all).with(id: 1).and_return([Tiime::Contact.new({ firstname: 'François',
                                                                                           lastname: 'de Metz' })])

      expect(Siign::Docage).to receive(:new).and_return(docage)
      expect(docage).to receive(:create_full_transaction)
        .with(
          'Test Quotation',
          instance_of(StringIO),
          {
            Email: 'francois@example.net',
            FirstName: 'François',
            LastName: 'de Metz',
            Address1: '2 avenue de l\'observatoire',
            Address2: nil,
            City: 'Paris',
            ZipCode: '75000',
            Country: 'France',
            Mobile: '+33600000000'
          },
          is_test: false,
          webhook: "http://example.org/webhook?secret=#{webhook_secret}"
        ).and_return(double(body: { 'Id' => 'iddocage' }))
      post '/devis/3'

      expect(last_response.headers['location']).to eq('http://example.org/devis')
      expect(Siign::Db.new(db_path).get_transaction_by_quote_id('3')).to eq('iddocage')
    end

    it 'disallow when the quote status is not saved' do
      post '/login', password: tiime_password
      expect_tiime_login
      expect(Tiime::Quotation).to receive(:find)
        .with(id: '3')
        .and_return(Tiime::Quotation.new(title: 'Test Quotation',
                                         status: 'accepted',
                                         client: Tiime::Quotation.new({ id: 1 })))
      post '/devis/3'

      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(403)
    end
  end
end
