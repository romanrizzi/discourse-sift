require_dependency 'post_serializer'

class SiftPostSerializer < PostSerializer
  attributes :excerpt

  def excerpt
    @excerpt ||= PrettyText.excerpt(cooked, 700, keep_emoji_images: true)
  end
end