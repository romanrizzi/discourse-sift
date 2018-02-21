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

    def silence
      # TODO: This just copies functionality from UsersController.silence
      # It would be nice to be able to just call that with the adjusted
      # date

      #Rails.logger.error("sift_debug: Silence Enter...")

      #Rails.logger.error("sift_debug: params = #{params.inspect}")
      
      user = User.find_by(id: params[:user_id])
            
      guardian.ensure_can_silence_user! user

      # If silenced_till is passed in, then use that
      # Otherwise use duration to calculate it
      silenced_till = params[:silenced_till]
      if silenced_till.nil?
        duration = params[:duration]
        unless duration.nil?
          # Calulate silenced_till by adding duration
          # Duration is passed as seconds
          temp_time = DateTime.now.to_time
          temp_time += duration.to_i
          silenced_till = temp_time.to_datetime
        end
      end

      # Message can be sent in request, or use i18n default
      # 
      message = params[:message]
      if message.nil?
        #Rails.logger.error("sift_debug: no message")
      
        message = I18n.t("sift.silence.message", params)
        #Rails.logger.error("sift_debug: message = #{message}")
      
      end

      # Reason can be sent in request, or use i18n default
      reason = params[:reason]
      if reason.nil?
        reason = I18n.t("sift.silence.reason", params)
      end

      silencer = UserSilencer.new(
        user,
        current_user,
        silenced_till: silenced_till,
        reason: reason,
        message_body: message,
        keep_posts: true
      )
      if silencer.silence && message.present?
        Jobs.enqueue(
          :critical_user_email,
          type: :account_silenced,
          user_id: user.id,
          user_history_id: silencer.user_history.id
        )
      end

      render_json_dump(
        silence: {
          silenced: true,
          silence_reason: silencer.user_history.try(:details),
          silenced_till: user.silenced_till,
          suspended_at: user.silenced_at
        }
      )
    end

    def suspend
      
      user = User.find_by(id: params[:user_id])
            
      guardian.ensure_can_suspend!(user)

      
      # If suspend_until is passed in, then use that
      # Otherwise use duration to calculate it
      suspend_until = params[:suspend_until]
      if suspend_until.nil?
        duration = params[:duration]
        unless duration.nil?
          # Calulate suspend_until by adding duration
          # Duration is passed as seconds
          temp_time = DateTime.now.to_time
          temp_time += duration.to_i
          suspend_until = temp_time.to_datetime
          params[:suspend_until] = suspend_until
        end
      end

      # Message can be sent in request, or use i18n default
      # 
      message = params[:message]
      if message.nil?
        #Rails.logger.error("sift_debug: no message")
      
        message = I18n.t("sift.suspend.message", params)
        #Rails.logger.error("sift_debug: message = #{message}")
        params[:message] = message
      end

      # Reason can be sent in request, or use i18n default
      reason = params[:reason]
      if reason.nil?
        reason = I18n.t("sift.suspend.reason", params)
        params[:reason] = reason
      end

      user.suspended_till = params[:suspend_until]
      user.suspended_at = DateTime.now

      message = params[:message]

      user_history = nil

      User.transaction do
        user.save!
        user.revoke_api_key

        user_history = StaffActionLogger.new(current_user).log_user_suspend(
          user,
          params[:reason],
          message: message,
          post_id: params[:post_id]
        )
      end
      user.logged_out

      if message.present?
        Jobs.enqueue(
          :critical_user_email,
          type: :account_suspended,
          user_id: user.id,
          user_history_id: user_history.id
        )
      end

      DiscourseEvent.trigger(
        :user_suspended,
        user: user,
        reason: params[:reason],
        message: message,
        user_history: user_history,
        post_id: params[:post_id],
        suspended_till: params[:suspend_until],
        suspended_at: DateTime.now
      )

      render_json_dump(
        suspension: {
          suspended: true,
          suspend_reason: params[:reason],
          full_suspend_reason: user_history.try(:details),
          suspended_till: user.suspended_till,
          suspended_at: user.suspended_at
        }
      )
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
