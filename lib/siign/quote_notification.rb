# frozen_string_literal: true

require 'faraday'

module Siign
  # Send quote notification
  class QuoteNotification
    def notify(status, quote_title, client_name)
      Notification.new.notify(notification_msg(status, quote_title, client_name))
    end

    private

    def notification_msg(status, quote_title, client_name)
      case status
      when :signed
        "Bonne nouvelle, devis #{quote_title} pour #{client_name} signé !"
      when :refused
        "Mauvaise nouvelle, devis #{quote_title} pour #{client_name} refusé !"
      when :expired
        "Sale nouvelle, devis #{quote_title} pour #{client_name} expiré !"
      when :aborted
        "Sale nouvelle, devis #{quote_title} pour #{client_name} annulé !"
      end
    end
  end
end
