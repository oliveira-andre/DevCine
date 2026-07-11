class AddMaturityRatingToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :maturity_rating, :integer, default: 0, null: false
  end
end
