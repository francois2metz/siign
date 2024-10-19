# frozen_string_literal: true

require 'rspec'
require 'siign'

RSpec.describe Siign::Notification do
  describe '#notify' do
    def expect_notification_message(message)
      expect(Faraday).to receive(:get).with("http://example.net/?message=#{ERB::Util.url_encode(message)}")
    end

    before do
      ENV['NOTIFICATION_URL'] = 'http://example.net/?message=${msg}'
    end

    it 'notify text' do
      expect_notification_message 'Hello world !'

      described_class.new.notify 'Hello world !'
    end

    it 'dont notify if there is no NOTIFICATION_URL' do
      ENV.delete('NOTIFICATION_URL')
      expect(Faraday).not_to receive(:get)

      described_class.new.notify 'Hello World'
    end

    it 'dont notify if msg is nil' do
      expect(Faraday).not_to receive(:get)

      described_class.new.notify nil
    end
  end
end
