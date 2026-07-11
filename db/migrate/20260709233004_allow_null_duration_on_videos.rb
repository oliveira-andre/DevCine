class AllowNullDurationOnVideos < ActiveRecord::Migration[8.0]
  def change
    # Duration is unknown until the (deferred) processing pipeline runs; uploads
    # leave it null until then.
    change_column_null :videos, :duration_seconds, true
  end
end
