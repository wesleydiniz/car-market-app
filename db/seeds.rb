BRANDS_DATA = JSON.parse(File.read('db/brands.json'))
CARS_DATA = JSON.parse(File.read('db/cars.json'))

BRANDS = BRANDS_DATA.each.with_object({}) do |brand_item, memo|
  brand_name = brand_item['name']
  memo[brand_name] = Brand.create!(name: brand_name)
end

CARS_DATA.each do |car_item|
  Car.create!(
    model: car_item['model'],
    brand: BRANDS[car_item['brand_name']],
    price: car_item['price'],
  )
end

User.create!(
  email: 'example@mail.com',
  preferred_price_range: 35_000...40_000,
  preferred_brands: [BRANDS['Alfa Romeo'], BRANDS['Volkswagen']],
)
