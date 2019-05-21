require 'date'

module DiscourseSift

  class SiftModQueueController < Admin::AdminController
    requires_plugin 'discourse-sift'

    def confirm_failed

      Rails.logger.debug("sift_debug: entered confirm failed")

      Sift::Client.with_client() do |client|
        post = Post.with_deleted.find(params[:post_id])
        client.submit_for_post_action(post, current_user,'agree', nil)
      end
      render body: nil
    end

    def disagree_due_to_false_positive
      Rails.logger.debug('sift_debug: entered disagree_due_to_false_positive')
      render body: nil
    end

    def disagree_due_to_too_strict
      Rails.logger.debug('sift_debug: entered disagree_due_to_too_strict')
      render body: nil
    end

    def disagree_due_to_user_edited
      Rails.logger.debug('sift_debug: entered disagree_due_to_user_edited')
      render body: nil
    end

    def disagree_due_to_other
      Rails.logger.debug('sift_debug: entered disagree_due_to_other')
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
