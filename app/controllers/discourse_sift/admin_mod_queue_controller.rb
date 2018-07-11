require 'date'

module DiscourseSift
  class AdminModQueueController < Admin::AdminController
    requires_plugin 'discourse-sift'


    def index
      render_json_dump(
          posts: serialize_data(DiscourseSift.requires_moderation, SiftPostSerializer),
          enabled: SiteSetting.sift_enabled?,
          stats: DiscourseSift.stats
      )
    end

    def confirm_failed
      post = Post.with_deleted.find(params[:post_id])

      # If post has not been deleted (i.e. if setting is on)
      # Then delete it now
      if !post.deleted_at

        #Rails.logger.error("sift_debug: Post not deleted.  Deleting now")
        
        PostDestroyer.new(current_user, post).destroy

        #Notify User?
        if SiteSetting.sift_notify_user
          SystemMessage.new(post.user).create(
            'sift_has_moderated',
            topic_title: post.topic.title
          )
        end
      end

      
      DiscourseSift.move_to_state(post, 'confirmed_failed')
      log_confirmation(post, 'confirmed_failed')
      render body: nil
    end

    def allow
      post = Post.with_deleted.find(params[:post_id])

      # It's possible the post was recovered already
      if post.deleted_at
        PostDestroyer.new(current_user, post).recover
      end

      DiscourseSift.move_to_state(post, 'confirmed_passed')
      log_confirmation(post, 'confirmed_passed')

      render body: nil
    end

    def dismiss
      post = Post.with_deleted.find(params[:post_id])

      DiscourseSift.move_to_state(post, 'dismissed')
      log_confirmation(post, 'dismissed')

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
