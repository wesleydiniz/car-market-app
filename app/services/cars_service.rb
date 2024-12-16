class CarsService

  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    begin
      return format_json(fetch_cars)
    rescue StandardError => e
      msg = 'Could not fetch recommended cars'
      puts "#{msg}. #{e.message}"
      return { error: msg }, status: :internal_server_error
    ensure
      clear_temporary_recommended_cars
    end
  end

  private

  def fetch_cars
    # Using Active Record caching to reduce database I/O
    Car.cache do
      # Fetches recommended cars and inserts temporary data for ranking
      fetch_recommended_cars_and_insert_temp_data
      query = Car.joins(:brand) # Joining with brands for filtering and display purposes

      # Applying search filters
      query = query.where('brands.name ILIKE ?', "%#{@params[:query]}%") if @params[:query].present?
      query = query.where('price >= ?', @params[:price_min].to_f) if @params[:price_min].present?
      query = query.where('price <= ?', @params[:price_max].to_f) if @params[:price_max].present?

      # Adding a join with the recommended_cars table
      query = query.left_joins(:recommended_cars) # Includes records without rank_score

      # Fetching user preferences for filtering and ranking
      user = User.find(@params[:user_id])
      user_preferred_brand_ids = user.preferred_brands.pluck(:id) # Gets IDs of preferred brands
      preferred_price_min = user.preferred_price_range.min || 0 # Minimum preferred price
      preferred_price_max = user.preferred_price_range.max || Float::MAX # Maximum preferred price

      # Adding the `label` field based on user preferences
      label_case = <<-SQL
      CASE
        WHEN cars.brand_id IN (#{user_preferred_brand_ids.join(',')})
             AND cars.price BETWEEN #{preferred_price_min} AND #{preferred_price_max} THEN 'perfect_match'
        WHEN cars.brand_id IN (#{user_preferred_brand_ids.join(',')}) THEN 'good_match'
        ELSE NULL
      END AS label
      SQL

      # Building the query with sorting
      ordered_query = query
                        .select('cars.*, brands.name AS brand_name, MAX(recommended_cars.rank_score) AS rank_score', label_case)
                        .group('cars.id, brands.id') # Groups by car and brand to avoid duplicates
                        .order(
                          # Sorting by `label`: perfect_match first, then good_match, then null
                          Arel.sql("CASE
          WHEN cars.brand_id IN (#{user_preferred_brand_ids.join(',')})
               AND cars.price BETWEEN #{preferred_price_min} AND #{preferred_price_max} THEN 0
          WHEN cars.brand_id IN (#{user_preferred_brand_ids.join(',')}) THEN 1
          ELSE 2 END"),
                          # Sorting by rank_score in descending order
                          Arel.sql("COALESCE(MAX(recommended_cars.rank_score), 0) DESC"),
                          # Sorting by price in ascending order
                          'cars.price ASC'
                        )

      # Applying pagination to limit the number of results
      page = @params[:page].to_i > 0 ? @params[:page].to_i : 1
      page_size = 100
      offset = (page - 1) * page_size
      ordered_query.limit(page_size).offset(offset)
    end
  end

  def fetch_recommended_cars_and_insert_temp_data
    car_rank_data = car_rank_data = Array(RecommendedCarsService.new(@user.id).call)
    car_rank_data.each do |data|
      RecommendedCar.create!(
        car_id: data["car_id"].to_i, # O car_id vai diretamente no campo correspondente.
        user_id: @user.id, # Relaciona o usuário com o registro.
        rank_score: data["rank_score"] # A pontuação.
      )
    end
  end

  def clear_temporary_recommended_cars
    RecommendedCar.where(user_id: @user.id).delete_all
  end

  def format_json(cars)
    cars.map do |car|
      {
        id: car.id,
        brand: { id: car.brand_id, name: car.brand_name },
        model: car.model,
        price: car.price,
        rank_score: car.rank_score,
        label: car.label
      }
    end.sort_by do |car|
      [car[:label] == 'perfect_match' ? 0 : car[:label] == 'good_match' ? 1 : 2, -car[:rank_score].to_f, car[:price]]
    end
  end

  def format_response(cars)
    cars.map do |car|
      {
        id: car[:id],
        brand: car[:brand],
        model: car[:model],
        price: car[:price],
        rank_score: car[:rank_score],
        label: car[:label]
      }
    end
  end

end