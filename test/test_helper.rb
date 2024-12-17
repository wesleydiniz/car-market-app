ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Configurações de teste
  # Opcional: adicionar fixture setup
  fixtures :all
end