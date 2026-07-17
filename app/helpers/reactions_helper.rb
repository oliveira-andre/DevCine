module ReactionsHelper
  # "video" / "comment" — used to build the polymorphic reactions route.
  def reactable_type(record)
    record.model_name.param_key
  end
end
