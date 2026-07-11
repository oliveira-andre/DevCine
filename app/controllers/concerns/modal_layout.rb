# Controllers whose new/edit actions render into the shared "modal" Turbo frame
# include this so a frame request returns only the frame (no surrounding layout,
# which would otherwise duplicate the layout's empty <turbo-frame id="modal">).
# Normal (non-frame) requests still get the full layout.
module ModalLayout
  extend ActiveSupport::Concern

  included do
    layout -> { false if turbo_frame_request? }
  end
end
