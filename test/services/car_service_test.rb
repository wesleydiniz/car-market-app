# test/services/cars_service_test.rb
require 'test_helper'

class CarsServiceTest < ActiveSupport::TestCase
  # Test if the call method returns a correctly formatted response when successful
  test 'should return formatted cars when the service call is successful' do
    user = users(:one) # Supondo que você tenha um fixture de usuário configurado
    params = { user_id: user.id, query: 'Toyota', price_min: 10000, price_max: 50000, page: 1 }

    # Stubbing the fetch_cars method to return mocked cars data
    cars = [
      Car.new(id: 1, brand_id: 1, brand_name: 'Toyota', model: 'Camry', price: 30000, rank_score: 8.5, label: 'perfect_match'),
      Car.new(id: 2, brand_id: 2, brand_name: 'Honda', model: 'Accord', price: 25000, rank_score: 7.5, label: 'good_match')
    ]

    # Stubbing the `fetch_cars` method within the service
    CarsService.any_instance.stubs(:fetch_cars).returns(cars)

    # Calling the service
    service = CarsService.new(user, params)
    result = service.call

    # Verifying that the result is in the expected format
    assert_includes result[:cars], { id: 1, brand: { id: 1, name: 'Toyota' }, model: 'Camry', price: 30000, rank_score: 8.5, label: 'perfect_match' }
    assert_includes result[:cars], { id: 2, brand: { id: 2, name: 'Honda' }, model: 'Accord', price: 25000, rank_score: 7.5, label: 'good_match' }
  end

  # Test if the service handles errors properly
  test 'should return an error response when an exception is raised' do
    user = users(:one)
    params = { user_id: user.id, query: 'BMW', price_min: 10000, price_max: 50000, page: 1 }

    # Simulating an exception being raised during the call
    CarsService.any_instance.stubs(:fetch_cars).raises(StandardError, 'Database error')

    service = CarsService.new(user, params)
    result = service.call

    # Verifying the error response
    assert_equal({ error: 'Could not fetch recommended cars' }, result.first)
    assert_equal :internal_server_error, result.last
  end

  # Test if the service correctly clears temporary recommended cars after execution
  test 'should clear temporary recommended cars after execution' do
    user = users(:one)
    params = { user_id: user.id, query: 'BMW', price_min: 10000, price_max: 50000, page: 1 }

    # Creating temporary recommended cars for the user
    RecommendedCar.create!(user_id: user.id, car_id: 1, rank_score: 8.5)
    RecommendedCar.create!(user_id: user.id, car_id: 2, rank_score: 7.5)

    service = CarsService.new(user, params)

    # Stubbing the fetch_cars method to avoid actual database queries
    CarsService.any_instance.stubs(:fetch_cars).returns([])

    # Calling the service
    service.call

    # Verifying that the temporary cars have been cleared
    assert_equal 0, RecommendedCar.where(user_id: user.id).count
  end

  # Test if the call method works correctly when no parameters are provided
  test 'should return empty cars list when no cars match the filters' do
    user = users(:one)
    params = { user_id: user.id, query: 'NonExistentBrand', price_min: 100000, price_max: 500000, page: 1 }

    service = CarsService.new(user, params)

    # Calling the service
    result = service.call

    # Verifying that the response contains an empty list of cars
    assert_equal [], result[:cars]
  end
end
