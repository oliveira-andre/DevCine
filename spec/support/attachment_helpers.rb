# Shared helper for attaching a small sample image to any Active Storage
# attachment, used by factory traits and specs.
module AttachmentHelpers
  SAMPLE_IMAGE = Rails.root.join("spec/fixtures/files/sample_image.jpg")

  def self.attach_sample(record, name, filename: "sample.jpg")
    record.public_send(name).attach(
      io: File.open(SAMPLE_IMAGE),
      filename: filename,
      content_type: "image/jpeg"
    )
  end
end
