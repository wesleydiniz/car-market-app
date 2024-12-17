class CreateUserPreferredBrands < ActiveRecord::Migration[6.1]
  def change
    create_table :user_preferred_brands do |t|
      t.references :user, null: false, foreign_key: true
      t.references :brand, null: false, foreign_key: true

      t.timestamps
    end
  end
end
