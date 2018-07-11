#
# Based on https://github.com/discourse/discourse-akismet/blob/master/jobs/check_akismet_post.rb
#
module Jobs
  class ClassifyPost < Jobs::Base

    # Send a post to Sift for classification
    def execute(args)
      #Rails.logger.debug("sift_debug: classify_post job: enter")
      raise Discourse::InvalidParameters.new(:post_id) unless args[:post_id].present?
      return unless SiteSetting.sift_enabled?

      post = Post.where(id: args[:post_id], user_deleted: false).first
      return unless post.present?

      #Rails.logger.debug("sift_debug: classify_post job: before classifiy")
      DiscourseSift.classify_post(post)
    end
  end
end
