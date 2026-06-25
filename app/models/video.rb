class Video < ApplicationRecord
  belongs_to :uploader

  has_many :episodes, dependent: :destroy
  has_many :movies, dependent: :destroy
  has_many :subtitles, dependent: :destroy
  has_many :video_views, dependent: :destroy
  has_many :watch_progresses, dependent: :destroy
  has_many :comments, dependent: :destroy

  has_many :likes, as: :likeable, dependent: :destroy
end
