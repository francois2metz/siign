# frozen_string_literal: true

$LOAD_PATH.unshift './lib'
require 'dotenv/load'
require 'siign'

run Siign::App
