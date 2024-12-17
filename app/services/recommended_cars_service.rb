class RecommendedCarsService
  require 'net/http'
  require 'json'

  def initialize(user_id)
    @user_id = user_id
    @redis_service = RedisService.new
  end

  def fetch_from_origin(user_id)
    url = "https://bravado-images-production.s3.amazonaws.com/recomended_cars.json?user_id=#{user_id}"
    Net::HTTP.get_response(URI.parse(url))
  end

  def fetch_recommended_cars_with_cache(user_id)
    cache_key = "recommended_cars:#{user_id}:5min"
    fallback_key = "recommended_cars:#{user_id}:24h"

    cached_response = @redis_service.get(cache_key)

    return JSON.parse(cached_response) if cached_response

    # if no cached response was found, fetch the origin
    response = fetch_from_origin(user_id)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      @redis_service.set(cache_key, data.to_json, ex: 300) # Cache for 5 minutes
      @redis_service.set(fallback_key, data.to_json, ex: 86_400) # Cache for 24 hours
      data
    else
      # if origin fails, try the 24h fallback cache
      fallback_response = @redis_service.get(fallback_key)
      fallback_response ? JSON.parse(fallback_response) : []
    end
  rescue StandardError => e
    puts "Could not get recommend card from AI service. #{e.message}"
  end

  def call
    fetch_recommended_cars_with_cache(@user_id)
  rescue StandardError
    []
  end
end