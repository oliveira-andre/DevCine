module MediaHelper
  # Renders an image for an Active Storage image attachment as a bounded
  # variant, falling back to an external URL (e.g. a Movie backdrop_key), then
  # to a CSS placeholder tile when nothing is available.
  # Renders a lazy-loaded image inside a wrapper that shows a loading spinner
  # until the image loads (then swaps it in), or a placeholder if the image
  # errors or none is available. The caller's `class:` goes on the wrapper so
  # existing layout classes (poster-card__img, hero__img) still position it.
  def poster_image_tag(attachment, external_url = nil, alt:, limit: [ 800, 800 ], **opts)
    wrapper_class = [ "media", opts.delete(:class) ].compact.join(" ")

    src =
      if attachment.respond_to?(:attached?) && attachment.attached?
        attachment.variant(resize_to_limit: limit)
      elsif external_url.present?
        external_url
      end

    if src.nil?
      return content_tag(:div, "", class: "#{wrapper_class} poster-placeholder",
                         role: "img", "aria-label": alt, **opts)
    end

    content_tag :div, class: wrapper_class, data: { controller: "lazy-image" }, **opts do
      concat content_tag(:span, icon(:spinner), class: "media__spinner",
                         data: { "lazy-image-target": "spinner" })
      concat image_tag(src, alt: alt, loading: "lazy", decoding: "async", class: "media__img",
                       data: { "lazy-image-target": "image",
                               action: "load->lazy-image#loaded error->lazy-image#failed" })
    end
  end

  # Normalizes the different home-rail record types into a common card shape.
  # :image is an Active Storage attachment, :external an optional fallback URL,
  # :preview an optional Video preview attachment (hover clip).
  def home_card(record)
    case record
    when Movie
      { title: record.title, image: record.poster, external: nil, preview: record.video&.preview }
    when Serie
      { title: record.title, image: record.poster, external: nil, preview: nil }
    when Video
      { title: record.title, image: record.thumbnail, external: nil, preview: record.preview }
    when WatchProgress, VideoView
      video = record.video
      { title: video.title, image: video.thumbnail, external: nil, preview: video.preview }
    else
      { title: record.try(:title).to_s, image: nil, external: nil, preview: nil }
    end
  end
end
