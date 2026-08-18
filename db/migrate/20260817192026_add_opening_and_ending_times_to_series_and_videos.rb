class AddOpeningAndEndingTimesToSeriesAndVideos < ActiveRecord::Migration[8.0]
  # Skip-intro / next-episode markers (seconds). The serie's values are the
  # default for all its episodes; a video's own values override for the odd
  # episode with a different opening or ending.
  def change
    add_column :series, :opening_time, :integer
    add_column :series, :ending_time, :integer
    add_column :videos, :opening_time, :integer
    add_column :videos, :ending_time, :integer
  end
end
