# name: discourse-sift
# about: supports content classifying of posts to Community Sift
# version: 0.1.1
# authors: Richard Kellar
# url: https://github.com/sift/discourse-sift

enabled_site_setting :sift_enabled

# load dependencies
load File.expand_path('../lib/discoursesift.rb', __FILE__)
load File.expand_path('../lib/sift.rb', __FILE__)
load File.expand_path('../lib/discourse_sift/engine.rb', __FILE__)

register_asset "stylesheets/mod_queue_styles.scss"

after_initialize do

  #
  # TODO:  Need to hook on post edits as well.  Any other hooks we need?
  #
  # TODO: Investigate "before_create_post", "validate_post", PostValidator, PostAnalyzer
  #
  # TODO: [minor] Admin moderation queue does not include topic title, which could be a small issue if the title
  #       of a new topic fails classification but the content is fine.  Minor issue, as moderator has access to the
  #       full topic from a link.
  # TODO: Title for new toics not classified

  # Store Sift Data
  on(:post_created) do |post, params|
    #Rails.logger.error("sift_debug: Enter post_created")
    if DiscourseSift.should_classify_post?(post)
      # Classify Post
      DiscourseSift.classify_post(post)
    end
  end

  on(:post_edited) do |post, params|
    #
    # TODO: If a post is edited, it is re-classified in it's entirety.  This could lead
    #       to:
    #         - Post created that fails classification
    #         - Moderator marks post as okay
    #         - user edits post
    #         - Post is reclassified, and the content that failed before will fail again
    #           even if new content would not fail
    #         - Post is marked for moderation again
    #  Not sure if this is a problem, but maybe there is a path forward that can classify
    #  a delta or something?
    #
    #Rails.logger.error("sift_debug: Enter post_edited")
    if DiscourseSift.should_classify_post?(post)
      # Classify Post
      DiscourseSift.classify_post(post)
    end
  end

  add_to_class(:guardian, :can_view_sift?) do
    user.try(:staff?)
  end

  add_to_serializer(:current_user, :sift_review_count) do
    scope.can_view_sift? ? DiscourseSift.requires_moderation.count : nil
  end

end

add_admin_route 'sift.title', 'sift'

# And mount the engine
Discourse::Application.routes.append do
  mount ::DiscourseSift::Engine, at: '/admin/plugins/sift'
end
