class CreateRecommendedCards < ActiveRecord::Migration[6.1]
  def change
    create_table :recommended_cars do |t|
      t.references :car, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :rank_score,
      t.timestamps
    end
  end
end
