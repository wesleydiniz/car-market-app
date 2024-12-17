require 'test_helper'
require 'mocha/minitest'

class CarsServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
    @params = {
      user_id: @user.id,
      query: 'Toyota',
      price_min: 10000,
      price_max: 50000,
      page: 1
    }
  end

  test "should successfully fetch and format cars" do
    # Stub external services and methods
    RecommendedCarsService.any_instance.stubs(:call).returns([
                                                               { "car_id" => 1, "rank_score" => 0.9123 },
                                                               { "car_id" => 2, "rank_score" => 0.8654},
                                                               { "car_id" => 3, "rank_score" => 0.8333 }
                                                             ])
    # Stub Car model methods
    cars = [cars(:corolla),
            cars(:civic),
            cars(:focus)]

    # Stub fetch_cars return
    CarsService.any_instance.stubs(:fetch_cars).returns([cars(:corolla), cars(:civic), cars(:focus)])

    # Create service instance and call method
    service = CarsService.new(@user, @params)
    result = service.call

    # Assertions
    assert_equal 3, result.size
    assert_equal 3, result.first[:id]
  end

  test "should handle errors gracefully" do
    # Stub to raise an error
    RecommendedCarsService.any_instance.stubs(:call).raises(StandardError.new("Test error"))

    # Create service instance and call method
    service = CarsService.new(@user, @params)
    result, status = service.call

    # Assertions for error handling
    assert_equal({ error: 'Could not fetch recommended cars' }, result)
    assert_equal :internal_server_error, status[:status]
  end

  test "should clear temporary recommended cars" do
    # Expect temporary cars to be deleted
    RecommendedCar.expects(:where).with(user_id: @user.id).returns(mock('relation', delete_all: true))

    # Create service instance and call method
    service = CarsService.new(@user, @params)
    service.send(:clear_temporary_recommended_cars)
  end

  test "should correctly format cars and sort them by label, rank_score, and price" do
    car1 = mock('car')
    car1.stubs(:id).returns(1)
    car1.stubs(:brand_id).returns(101)
    car1.stubs(:brand_name).returns('Toyota')
    car1.stubs(:model).returns('Corolla')
    car1.stubs(:price).returns(20000)
    car1.stubs(:rank_score).returns(0.95)
    car1.stubs(:label).returns('perfect_match')

    car2 = mock('car')
    car2.stubs(:id).returns(2)
    car2.stubs(:brand_id).returns(102)
    car2.stubs(:brand_name).returns(nil)
    car2.stubs(:model).returns('Civic')
    car2.stubs(:price).returns(18000)
    car2.stubs(:rank_score).returns(nil)
    car2.stubs(:label).returns(nil)

    car3 = mock('car')
    car3.stubs(:id).returns(3)
    car3.stubs(:brand_id).returns(103)
    car3.stubs(:brand_name).returns('Ford')
    car3.stubs(:model).returns('Focus')
    car3.stubs(:price).returns(15000)
    car3.stubs(:label).returns('perfect_match')
    car3.stubs(:rank_score).returns(0.75)

    cars = [car1,car2,car3]

    expected_result = [
      {
        id: 1,
        brand: { id: 101, name: 'Toyota' },
        model: 'Corolla',
        price: 20000,
        rank_score: 0.95,
        label: 'perfect_match'
      },
      {
        id: 3,
        brand: { id: 103, name: 'Ford' },
        model: 'Focus',
        price: 15000,
        rank_score: 0.75,
        label: 'perfect_match'
      },
      {
        id: 2,
        brand: { id: 102, name: nil },
        model: 'Civic',
        price: 18000,
        rank_score: nil,
        label: nil
      }
    ]

    service = CarsService.new(@user, @params)
    result = service.send(:format_json, cars)

    assert_equal expected_result, result
  end

  def test_fetch_recommended_cars_and_insert_temp_data
    recommended_data = [
      { "car_id" => 1, "rank_score" => 0.9123 },
      { "car_id" => 2, "rank_score" => 0.8654 },
      { "car_id" => 3, "rank_score" => 0.8333 }
    ]

    RecommendedCarsService.any_instance.stubs(:call).returns(recommended_data)

    RecommendedCar.expects(:create!).with(has_entries(car_id: 1, user_id: @user.id, rank_score: 0.9123))
    RecommendedCar.expects(:create!).with(has_entries(car_id: 2, user_id: @user.id, rank_score: 0.8654))
    RecommendedCar.expects(:create!).with(has_entries(car_id: 3, user_id: @user.id, rank_score: 0.8333))

    CarsService.new(@user,@params).send(:fetch_recommended_cars_and_insert_temp_data)
  end
end