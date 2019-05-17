require 'date'

module DiscourseSift

  class SiftModQueueController < Admin::AdminController
    requires_plugin 'discourse-sift'

    def confirm_failed

      Rails.logger.debug("sift_debug: entered confirm failed")
      render body: nil
    end

    def allow
      Rails.logger.debug("sift_debug: entered allow")
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
