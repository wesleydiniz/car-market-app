class RedisService
  require 'redis'

  def initialize
    @redis = Redis.new
  end

  def get(key)
    cached_response = nil
    begin
      cached_response = @redis.get(key)
    rescue StandardError => e
      puts "Could not get key from redis. #{e.message}"
    end
    cached_response
  end

  def set(key, data, ttl)
    begin
      @redis.set(key, data.to_json, ex: ttl)
    rescue StandardError => e
      puts "Failure saving redis entry. Key: #{key}\n#{e.message}"
    end
  end
end