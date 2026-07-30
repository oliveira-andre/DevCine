module Settings
  # Persists the viewer's subtitle preferences (feature 012). The player applies
  # changes live client-side; this just makes them durable across videos/sessions.
  class SubtitlesController < ApplicationController
    def update
      if Current.user.update(subtitle_params)
        head :no_content
      else
        render json: { errors: Current.user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def subtitle_params
      params.permit(
        :subtitles_enabled, :subtitle_text_color, :subtitle_background_color,
        :subtitle_font_size, :subtitle_font_weight
      )
    end
  end
end
