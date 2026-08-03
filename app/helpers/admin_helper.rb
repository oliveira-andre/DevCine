module AdminHelper
  # True on any /admin page. Drives the layout's chrome choice (admin header +
  # left drawer nav) and is why crossing between the app and admin must be a
  # full Turbo Drive visit, not a #page-content stream swap — the whole chrome
  # differs between the two.
  def admin_context?
    request.path.start_with?("/admin")
  end

  # One admin nav entry. `match` is a path prefix so a section stays active on
  # its sub-pages (a user's detail page keeps "Users" lit).
  def admin_nav_link(label, icon_name, path, match: path)
    active = request.path == match || request.path.start_with?("#{match}/")
    link_to path, class: "admin-nav__link#{' is-active' if active}",
                  "aria-current": (active ? "page" : nil),
                  data: { action: "drawer#close" } do
      safe_join([ icon(icon_name), tag.span(label) ])
    end
  end

  # Role pill on the admin user list/detail. Blocked and admin are colour-coded
  # because those are the two states worth spotting at a glance in a long list.
  def user_role_badge(user)
    tag.span user.role.to_s.titleize, class: "admin-badge admin-badge--#{user.role}"
  end

  # Visibility pill for a video row on an admin surface, where listings are
  # unscoped and a title's visibility would otherwise be invisible.
  def video_visibility_badge(video)
    tag.span video.visibility.to_s.titleize, class: "admin-chip"
  end

  # Whether this admin is cleared to see a non-public title right now.
  def admin_may_see?(video)
    video.visibility_public? || pin_unlocked?
  end

  # Titles also leak through surfaces that merely REFERENCE a video — the video
  # a comment sits on, the members of a playlist. Mask those the same way the
  # video lists are masked, or the PIN gate is trivially side-stepped.
  def admin_video_title(video)
    admin_may_see?(video) ? video.title : "Hidden title"
  end

  # Compact running time for an admin detail panel: "1:04:09" or "4:09".
  def admin_duration(seconds)
    total = seconds.to_i
    return nil if total <= 0

    hours = total / 3600
    minutes = (total % 3600) / 60
    secs = total % 60
    if hours.positive?
      format("%d:%02d:%02d", hours, minutes, secs)
    else
      format("%d:%02d", minutes, secs)
    end
  end
end
