class Car < ApplicationRecord
  belongs_to :brand
  has_many :recommended_cars, dependent: :destroy
end
