# name: discourse-sift
# about: supports content classifying of posts to Community Sift
# version: 0.1.0
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

  # Store Sift Data
  on(:post_created) do |post, params|
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