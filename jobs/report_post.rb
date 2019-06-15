#
# Based on https://github.com/discourse/discourse-akismet/blob/master/jobs/check_akismet_post.rb
#
module Jobs
  class ReportPost < Jobs::Base

    # Send a post to Sift to report aggee or disagree with classification
    def execute(args)
      #Rails.logger.debug("sift_debug: report_post job: enter")
      raise Discourse::InvalidParameters.new(:post_id) unless args[:post_id].present?
      return unless SiteSetting.sift_enabled?

      post = Post.where(id: args[:post_id], user_deleted: false).first
      return unless post.present?

      Sift::Client.with_client do |client|
        moderator_id = args[:moderator_id]
        moderator = User.where(id: moderator_id).first
        reason = args[:reason]
        extra_reason_remarks = args[:extra_reason_remarks]

        client.submit_for_post_action(post, moderator, reason, extra_reason_remarks)
      end
    end
  end
end
