require 'date'

module DiscourseSift

  class SiftModQueueController < Admin::AdminController
    requires_plugin 'discourse-sift'

    def confirm_failed

      #Rails.logger.debug("sift_debug: entered confirm failed")

      post = Post.with_deleted.find(params[:post_id])

      DiscourseSift.report_post(post, current_user,'agree', nil)

      render body: nil
    end

    def disagree
      #Rails.logger.debug("sift_debug: disagree: enter")
      post = Post.with_deleted.find(params[:post_id])
      reason = params[:reason]
      #Rails.logger.debug("sift_debug: disagree: self='#{post.inspect}', reason='#{reason}'")
      DiscourseSift.report_post(post, current_user, reason, nil)
      render body: nil
      end

    def disagree_other
      #Rails.logger.debug("sift_debug: disagree_other: enter'")
      post = Post.with_deleted.find(params[:post_id])
      reason = params[:reason]
      other_reason = params[:other_reason]
      #Rails.logger.debug("sift_debug: disagree_other: self='#{post.inspect}', reason='#{reason}', extra_reason = '#{other_reason}'")
      DiscourseSift.report_post(post, current_user, reason, other_reason)

      render body: nil
    end

    private

    def log_confirmation(post, custom_type)
      topic = post.topic || Topic.with_deleted.find(post.topic_id)

      StaffActionLogger.new(current_user).log_custom(custom_type,
                                                     post_id: post.id,
                                                     topic_id: topic.id,
                                                     created_at: post.created_at,
                                                     topic: topic.title,
                                                     post_number: post.post_number,
                                                     raw: post.raw
      )
    end

  end
end
