ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/kindness_lesson_builder"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Rate-limit counters live in the (memory) cache store; without this a
    # test file that signs in or pairs repeatedly trips limits meant for
    # attackers, not suites.
    setup { Rails.cache.clear }

    # Add more helper methods to be used by all tests here...
  end
end
