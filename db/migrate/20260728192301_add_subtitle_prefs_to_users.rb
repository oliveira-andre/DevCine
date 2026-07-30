class AddSubtitlePrefsToUsers < ActiveRecord::Migration[8.0]
  def change
    # Per-user subtitle preferences (feature 012). Defaults: off, white text on a
    # black background, 100% size, normal weight. NULL background = transparent.
    add_column :users, :subtitles_enabled, :boolean, null: false, default: false
    add_column :users, :subtitle_text_color, :string, null: false, default: "#FFFFFF"
    add_column :users, :subtitle_background_color, :string, default: "#000000"
    add_column :users, :subtitle_font_size, :integer, null: false, default: 100
    add_column :users, :subtitle_font_weight, :integer, null: false, default: 400
  end
end
