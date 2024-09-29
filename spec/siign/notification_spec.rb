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

    it 'notify the signed case' do
      expect_notification_message 'Bonne nouvelle, devis Test Quotation signé !'

      described_class.new.notify :signed, 'Test Quotation'
    end

    it 'notify the refused case' do
      expect_notification_message 'Mauvaise nouvelle, devis Test Quotation refusé !'

      described_class.new.notify :refused, 'Test Quotation'
    end

    it 'notify the expired case' do
      expect_notification_message 'Sale nouvelle, devis Test Quotation expiré !'

      described_class.new.notify :expired, 'Test Quotation'
    end

    it 'notify the aborted case' do
      expect_notification_message 'Sale nouvelle, devis Test Quotation annulé !'

      described_class.new.notify :aborted, 'Test Quotation'
    end

    it 'dont notify if there is no NOTIFICATION_URL' do
      ENV.delete('NOTIFICATION_URL')
      expect(Faraday).not_to receive(:get)

      described_class.new.notify :signed, 'Test Quotation'
    end

    %i[
      draft
      scheduled
      waitinginformations
      active
      validated
    ].each do |status|
      it "notify nothing in the #{status} case" do
        expect(Faraday).not_to receive(:get)

        described_class.new.notify status, 'Test Quotation'
      end
    end
  end
end
