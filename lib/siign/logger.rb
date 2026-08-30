# frozen_string_literal: true

# Siign logger
module Siign
  def self.logger
    @logger || ::Logger.new(ENV['LOG_FILE'] || $stdout, progname: 'siign', level: ENV['LOG_LEVEL'] || 'debug')
  end
end
