module Settings
  # Toggles the viewer's per-user autoplay preference (feature 010, US5). Default
  # is ON; the control lives on the player page and persists across sessions.
  class AutoplaysController < ApplicationController
    def update
      Current.user.update(autoplay: !Current.user.autoplay)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "autoplay_toggle", partial: "player/autoplay_toggle"
          )
        end
        format.html { redirect_back fallback_location: root_path }
      end
    end
  end
end
