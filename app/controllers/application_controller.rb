class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError do
    raise ActiveRecord::RecordNotFound
  end

  # Policies receive the viewer AND the PIN-unlock state (feature 006, FR-017).
  def pundit_user
    AuthContext.new(user: Current.user, pin_unlocked: pin_unlocked?)
  end

  # Spotsby-style navigation shell (feature 010 refactor). In-app links opt into
  # turbo_stream navigation; ordinary actions with no dedicated *.turbo_stream.erb
  # answer by re-rendering just the page body into the #page-content div — the
  # persistent mini-player is a SIBLING of that div, so navigation never touches
  # it. `flash[:_full_render]` forces a classic full-page render when needed.
  def default_render(*args)
    # Read AND consume the one-shot flag. Rails' flash is lazy: if no request ever
    # touches it, a stale flag would survive extra requests and hijack the user's
    # next stream navigation into a full render. delete() makes it one-shot here.
    # NOTE: FlashHash#delete returns the hash (not the value) — read first.
    full_render = flash[:_full_render]
    flash.delete(:_full_render)

    if request.format.turbo_stream? && !turbo_stream_template_exists?
      if turbo_frame_request?
        # A form inside a Turbo frame (e.g. the modal) submitted and got
        # redirected here: the follow-up GET keeps the form's turbo_stream
        # Accept header AND the Turbo-Frame header. Answer with plain HTML so
        # Turbo swaps the frame's content (modal→modal redirect) instead of
        # streaming a second copy of the view into #page-content.
        render action_name, formats: :html
      elsif full_render
        # Auth transitions etc.: the chrome changed, deliver a full page. Turbo
        # degrades the stream link to a normal Drive visit on an html response.
        render action_name, formats: :html
      else
        # The toast stack lives in the layout, which this path skips — refresh it
        # alongside the body so redirect notices/alerts survive stream navigation
        # (and an empty render clears stale toasts).
        banners = render_to_string(partial: "shared/flash", formats: :html)
        body = render_to_string(action_name, formats: :html, layout: false)
        # Undo render_to_string side effects: it mutates lookup_context.formats to
        # :html (which would wrap the stream in the application layout) and leaves
        # text/html on the response (which turbo-rails would then keep).
        lookup_context.formats = [ :turbo_stream ]
        response.content_type = nil
        render turbo_stream: [
          turbo_stream.update("page-content", body),
          turbo_stream.update("flash", banners)
        ], layout: false
      end
    else
      # Dedicated *.turbo_stream.erb templates and plain HTML requests are never
      # affected — even by a stale _full_render flag.
      super
    end
  end

  def turbo_stream_template_exists?
    lookup_context.exists?(action_name, _prefixes, false, [], formats: [ :turbo_stream ])
  end

  private

  def pin_unlocked?
    token = request.headers["X-Pin-Unlock"]
    expected = session[:pin_unlock_token]
    token.present? && expected.present? &&
      ActiveSupport::SecurityUtils.secure_compare(token, expected)
  end
  helper_method :pin_unlocked?
end
