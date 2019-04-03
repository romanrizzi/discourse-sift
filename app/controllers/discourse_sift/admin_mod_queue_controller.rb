require 'date'

module DiscourseSift
  class AdminModQueueController < Admin::AdminController
    requires_plugin 'discourse-sift'

    before_action :deprecation_notice

    def index
      render_json_dump(
          posts: serialize_data(DiscourseSift.requires_moderation, SiftPostSerializer),
          enabled: SiteSetting.sift_enabled?,
          stats: DiscourseSift.stats
      )
    end

    def confirm_failed
      if should_use_reviewable_api?
        reviewable.perform(current_user, :confirm_failed)
      else
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
      end
      
      render body: nil
    end

    def allow
      if should_use_reviewable_api?
        reviewable.perform(current_user, :allow)
      else
        # It's possible the post was recovered already
        if post.deleted_at
          PostDestroyer.new(current_user, post).recover
        end

        DiscourseSift.move_to_state(post, 'confirmed_passed')
        log_confirmation(post, 'confirmed_passed')
      end

      render body: nil
    end

    def dismiss
      if should_use_reviewable_api?
        reviewable.perform(current_user, :ignore)
      else
        DiscourseSift.move_to_state(post, 'dismissed')
        log_confirmation(post, 'dismissed')
      end

      render body: nil
    end

    private

    def log_confirmation(post, custom_type)
      StaffActionLogger.new(current_user).log_custom(
        custom_type, post_id: post.id, topic_id: post.topic_id,
      )
    end

    def should_use_reviewable_api?
      defined?(ReviewableSiftPost) && reviewable
    end

    def deprecation_notice
      Discourse.deprecate('Sift review queue is deprecated. Please use the reviewable API instead.')
    end

    def reviewable
      @reviewable ||= ReviewableSiftPost.find_by(target_id: params[:post_id], target_type: Post.name)
    end

    def post
      @post ||= Post.with_deleted.find(params[:post_id])
    end
  end
end
