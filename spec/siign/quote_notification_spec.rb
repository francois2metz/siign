# frozen_string_literal: true

require 'rspec'
require 'siign'

RSpec.describe Siign::QuoteNotification do
  describe '#notify' do
    let(:notification) { instance_double(Siign::Notification) }

    def expect_notification_message(message)
      allow(Siign::Notification).to receive(:new).and_return(notification)
      expect(notification).to receive(:notify).with(message)
    end

    it 'notify the signed case' do
      expect_notification_message 'Bonne nouvelle, devis Test Quotation pour Awesome Client signé !'

      described_class.new.notify :signed, 'Test Quotation', 'Awesome Client'
    end

    it 'notify the refused case' do
      expect_notification_message 'Mauvaise nouvelle, devis Test Quotation pour Awesome Client refusé !'

      described_class.new.notify :refused, 'Test Quotation', 'Awesome Client'
    end

    it 'notify the expired case' do
      expect_notification_message 'Sale nouvelle, devis Test Quotation pour Awesome Client expiré !'

      described_class.new.notify :expired, 'Test Quotation', 'Awesome Client'
    end

    it 'notify the aborted case' do
      expect_notification_message 'Sale nouvelle, devis Test Quotation pour Awesome Client annulé !'

      described_class.new.notify :aborted, 'Test Quotation', 'Awesome Client'
    end

    it 'notify nothing in the draft case' do
      expect_notification_message nil

      described_class.new.notify :draft, 'Test Quotation', 'Awesome Client'
    end
  end
end
