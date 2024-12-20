class CarsController < ApplicationController


  def initialize
    @redis = RedisService.new
  end
  def recommended
    validated_params = validate_parameters

    redis_key = generate_redis_key(validated_params)
    cache_response = @redis.get(redis_key)
    return render json: cache_response if cache_response

    user = UsersService.new.find(validated_params[:user_id])
    if user.nil?
      return render json: { error: 'User not found' }, status: :not_found
    end

    cars = CarsService.new(user, validated_params).call

    if cars.nil?
      return render json: { error: 'Cars not found' }, status: :not_found
    end

    @redis.set(redis_key, cars, 30)
    render json: cars
  end

  def validate_parameters
    params.except(:car).permit(:user_id, :query, :price_min, :price_max, :page)
  end

  def generate_redis_key(params)
    "general_cache:user(#{params['user_id']}):query(#{params['query']}):price_min(#{params['price_min']}):price_max(#{params['price_max']}):page(#{params['page']}):"
  end
end