# Car Market Solution

# Getting started

#### Starting Redis server
    docker compose up

#### Installing dependencies
    bundle install

#### Setup database
    rake db:setup
or for tests:

    rake db:setup RAILS_ENV=test

#### Executing tests
    rails test

#### Starting application
    rails server

#### Calling the endpoint
    curl --location --request GET 'http://127.0.0.1:3000/cars/recommended' \
    --header 'Content-Type: application/json' \
    --data '{
    "user_id": 1,
    "page": 1,
    "query": "Volks",
    "price_max": 36000
    }'



## Overview

The solution focuses on solving performance issues by offloading heavy sorting and filtering logic directly to the database, using SQL queries. To achieve this, I decided to temporarily store the AI service's data in a database table (recommended_cars).

Additionally, Redis is utilized to cache the results, minimizing database load and improving response times. This approach ensures that the application handles large datasets efficiently without degrading performance.

## Key Features:
- **Efficient Database Queries**: Sorting, filtering, and ranking are executed in the database to leverage its optimized capabilities.
- **Caching with Redis**: Cache layers are implemented using Redis to store frequently requested data and reduce database I/O.
- **Robust Error Handling**: If the cache or external service fails, fallback mechanisms are provided to ensure the system remains functional.

## Main Components:

### 1. **CarsController**
The `CarsController` is responsible for handling HTTP requests related to fetching recommended cars. It performs the following tasks:
- **Redis Caching**: Checks if the requested data is available in Redis cache before querying the database.
- **User Validation**: Ensures the user exists before proceeding with fetching car recommendations.
- **Car Fetching**: Calls the `CarsService` to fetch and return the recommended cars.
- **Redis Key Generation**: A unique Redis key is generated to store and retrieve cached car data for each specific request.

#### Methods:

- **`recommended`**:
   - Validates input parameters and generates a Redis key.
   - Attempts to fetch the cached response from Redis. If found, returns it.
   - If the cache is empty, fetches data from the database using the `CarsService`.
   - Caches the response for future use and returns the final result in JSON format.

- **`car_params`**:
   - Defines the expected input parameters, including `user_id`, `query`, `price_min`, `price_max`, and `page`.

- **`generate_redis_key`**:
   - Generates a unique Redis key for storing the cached data based on query parameters.

### 2. **RecommendedCarsService**
This service is responsible for interacting with an external source to fetch recommended cars based on the user ID. It also implements caching to reduce external API calls.

#### Methods:

- **`fetch_from_origin`**:
   - Makes a network request to fetch recommended cars from an external API.

- **`fetch_recommended_cars_with_cache`**:
   - First checks if cached data is available in Redis.
   - If no cache is found, fetches data from the origin (external API), then caches the result for both short-term (5 minutes) and long-term (24 hours).
   - If the external API fails, it falls back to the 24-hour cache.

- **`call`**:
   - Fetches the recommended cars using the `fetch_recommended_cars_with_cache` method. Returns the cached data or the fetched data if the cache is empty.

### 3. **CarsService**
This service is the core of this solution. It handles the logic for fetching cars from the database, applying filters, and performing sorting. It also handles the insertion and clearing of temporary car ranking data.

#### Methods:

- **`call`**:
   - The main method for fetching cars. It calls `fetch_cars`, formats the results, and handles any errors.
   - If an error occurs, it returns an appropriate error message.

- **`fetch_cars`**:
   - Fetches the car data using ActiveRecord and SQL joins. It includes:
      - **Filtering**: Filters cars based on the query, minimum and maximum prices.
      - **Joining**: Joins the `cars`, `brands`, and `recommended_cars` (a kind of temporary table) tables to fetch all necessary data.
      - **User Preferences**: Retrieves user preferences (preferred brands and price range) for custom filtering.
      - **Sorting**: Applies a custom SQL `ORDER BY` clause to sort the cars by preference, rank score, and price.
      - **Pagination**: Applies pagination to limit the results returned.

- **`fetch_recommended_cars_and_insert_temp_data`**:
   - Fetches recommended car data from the `RecommendedCarsService` and inserts temporary ranking data into the `recommended_cars` table.

- **`clear_temporary_recommended_cars`**:
   - Clears the temporary data from the `recommended_cars` table to keep the database clean.

- **`format_json`**:
   - Formats the car data into a JSON response.
   - Sorts the cars by preference (`perfect_match`, `good_match`), rank score, and price.

## Performance Considerations:
1. **Database Efficiency**:
   - All heavy filtering and sorting logic is pushed to the database using SQL queries, which is optimized for such operations.
   - By using database joins and grouping, we avoid unnecessary application-level processing, reducing CPU load.

2. **Caching with Redis**:
   - Redis is used to cache the recommended car data for specific user queries, which avoids repeated database hits and external API calls.
   - Two cache layers are used:
      - A **short-term cache** (5 minutes) stores the most recent car recommendations.
      - A **long-term cache** (24 hours) ensures that even if the short-term cache expires, the system can still return data without making new requests.

3. **Error Handling**:
   - Fallback mechanisms ensure that if either the cache or external service fails, the system can still return reasonable results using cached data or an empty set.


