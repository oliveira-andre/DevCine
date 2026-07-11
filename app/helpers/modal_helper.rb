module ModalHelper
  # Renders modal content inside the shared "modal" Turbo frame as a <dialog>.
  # Used by every new/edit form (change password, upload, avatar) — the
  # constitution's reusable modal.
  #
  #   <%= modal title: "Change password" do %>
  #     <%= form_with ... %>
  #   <% end %>
  def modal(title: nil, size: nil)
    body = capture { yield }
    dialog_class = [ "modal", ("modal--#{size}" if size) ].compact.join(" ")

    turbo_frame_tag "modal" do
      content_tag(:dialog, class: dialog_class,
                  data: { controller: "modal", action: "click->modal#backdrop close->modal#onClose" }) do
        content_tag(:div, class: "modal__panel", role: "dialog", "aria-modal": "true") do
          head = content_tag(:div, class: "modal__head") do
            safe_join([
              (content_tag(:h2, title, class: "modal__title") if title.present?),
              button_tag("✕", type: "button", class: "modal__close",
                         data: { action: "modal#close" }, "aria-label": "Close")
            ].compact)
          end
          safe_join([ head, body ])
        end
      end
    end
  end

  # Turbo Stream that closes the modal (empties the shared frame).
  def close_modal_stream
    turbo_stream.update("modal", "")
  end
end
