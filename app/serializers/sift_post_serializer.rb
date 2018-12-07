require_dependency 'post_serializer'

class SiftPostSerializer < PostSerializer
  attributes :sift_excerpt

  def sift_excerpt
    @sift_excerpt ||= PrettyText.excerpt(cooked, 700, keep_emoji_images: true)
  end
end
