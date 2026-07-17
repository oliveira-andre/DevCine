# A movie is visible exactly when its feature video is (feature 006).
class MoviePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:video).merge(VideoPolicy::Scope.new(user, Video).resolve)
    end
  end
end
