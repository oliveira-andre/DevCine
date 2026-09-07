class AddHlsReadyAtToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :hls_ready_at, :datetime
  end
end
