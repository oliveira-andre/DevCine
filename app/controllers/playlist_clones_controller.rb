# Saving ("save" / "grab" / "clone" — all the same action) a public playlist
# takes a copy under the current user, which they are then free to add to or
# trim without touching the original.
class PlaylistClonesController < ApplicationController
  def create
    source = Playlist.find(params[:id])
    # Same gate as viewing it: you can only save what you are allowed to see.
    authorize source, :show?

    copy = source.save_copy_for(Current.user, pundit_user)

    # Stream navigation swaps #page-content without advancing the URL, which
    # would leave the address bar on the ORIGINAL while showing the copy — a
    # reload would then look like the save was lost. This redirect crosses to a
    # different record, so force a real navigation.
    flash[:_full_render] = true
    redirect_to playlist_path(copy), notice: saved_notice(source, copy)
  end

  private

    # Saving twice is idempotent, so say which of the two happened rather than
    # claiming a copy was made when the user was just sent to their existing one.
    def saved_notice(source, copy)
      if copy.previously_new_record?
        "Saved “#{source.title}” to your playlists."
      else
        "You already saved “#{source.title}”."
      end
    end
end
