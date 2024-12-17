require 'test_helper'
require 'mocha/minitest'

class CarsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Create a mock user
    @user = mock('User')
    @user.stubs(:id).returns(1)  # Set an id for the user

    # Create instances for RedisService, UsersService, and CarsService
    @redis = mock('RedisService')
    RedisService.stubs(:new).returns(@redis)
    @cars_service = mock('CarsService')
    CarsService.stubs(:new).returns(@cars_service)

    @controller = CarsController.new
  end

  def test_recommended_cache_hit
    # Simulate cache key being found
    redis_key = "general_cache:user(1):query(sedan):price_min(10000):price_max(50000):page(1):"
    cached_data = { cars: ['Car 1', 'Car 2'] }
    @redis.stubs(:get).with(redis_key).returns(cached_data.to_json)

    # Perform the request to the controller
    get cars_recommended_path(user_id: 1, query: 'sedan', price_min: 10000, price_max: 50000, page: 1)

    # Check if the response is from the cache
    assert_response :success
    assert_equal cached_data.to_json, response.body
  end

  def test_recommended_user_not_found
    # Simulate the case where the user is not found
    @redis.stubs(:get).returns(nil)
    UsersService.any_instance.stubs(:find).returns(nil)

    # Perform the request to the controller
    get cars_recommended_path(user_id: 1, query: 'sedan', price_min: 10000, price_max: 50000, page: 1)

    # Check if the error response was rendered
    assert_response :not_found
    assert_includes response.body, 'User not found'
  end

  def test_recommended_cars_not_found
    # Simulate the case where no cars are found
    @redis.stubs(:get).returns(nil)
    UsersService.any_instance.stubs(:find).returns(@user)
    @cars_service.stubs(:call).returns(nil)

    # Perform the request to the controller
    get cars_recommended_path(user_id: 1, query: 'sedan', price_min: 10000, price_max: 50000, page: 1)

    # Check if the error response was rendered
    assert_response :not_found
    assert_includes response.body, 'Cars not found'
  end

  def test_recommended_successful
    # Simulate a valid response from the CarsService
    @redis.stubs(:get).returns(nil)
    UsersService.any_instance.stubs(:find).returns(@user)
    cars_data = [{ id: 1, brand: 'Toyota', model: 'Corolla', price: 20000 }]
    @cars_service.stubs(:call).returns(cars_data)

    # Ensure the Redis `set` method is called to cache the results
    @redis.expects(:set).with("general_cache:user(1):query(sedan):price_min(10000):price_max(50000):page(1):", cars_data, 30)

    # Perform the request to the controller
    get cars_recommended_path(user_id: 1, query: 'sedan', price_min: 10000, price_max: 50000, page: 1)

    # Check if the response was successful
    assert_response :success
    assert_includes response.body, 'Toyota'
    assert_includes response.body, 'Corolla'
  end

  def test_generate_redis_key
    # Test the generation of the Redis key
    params = { 'user_id' => '1', 'query' => 'sedan', 'price_min' => '10000', 'price_max' => '50000', 'page' => '1' }
    expected_key = "general_cache:user(1):query(sedan):price_min(10000):price_max(50000):page(1):"
    actual_key = @controller.generate_redis_key(params)

    assert_equal expected_key, actual_key
  end
end
