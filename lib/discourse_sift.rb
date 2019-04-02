module DiscourseSift

  RESPONSE_CUSTOM_FIELD ||= "sift".freeze

  def self.should_classify_post?(post)
    return false if post.blank? || (!SiteSetting.sift_enabled?)

    #Don't Classify Private Messages
    return false if post.topic.private_message?

    stripped = post.raw.strip


    # If the entire post is a URI we skip it. This might seem counter intuitive but
    # Discourse already has settings for max links and images for new users. If they
    # pass it means the administrator specifically allowed them.
    uri = URI(stripped) rescue nil
    return false if uri

    # Otherwise check the post!
    true

  end

  def self.with_client
    Sift::Client.with_client(
        base_url: Discourse.base_url,
        api_key: SiteSetting.sift_api_key,
        api_url: SiteSetting.sift_api_url,
        end_point: SiteSetting.sift_end_point,
        ) do |client|

      yield client
    end
  end

  def self.classify_post(post)
    DiscourseSift.with_client do |client|
      #Rails.logger.error("sift_debug: classify_post Enter: #{post.inspect}")

      result = client.submit_for_classification(post)
      passes_policy_guide = result.response

      if passes_policy_guide
        # Make post as passed policy guide
        DiscourseSift.move_to_state(post, 'pass_policy_guide')
      elsif result.over_any_max_risk
        # Mark Post As Auto Moderated Queue
        DiscourseSift.move_to_state(post, 'auto_moderated')

        remove_post_and_notify(post, 'sift_auto_filtered')

        # Trigger an event that community sift auto moderated a post. This allows moderators to notify chat rooms
        DiscourseEvent.trigger(:sift_auto_moderated)
      else
        #
        # TODO: If a user is on the post's page and is following the topic then they see the post appear.  It stays
        #       in view until they refresh the topic even if it was sent to moderated and/or deleted.  Is there a
        #       hook that can prevent that (i.e. filter the post before it can show on a page? earlier hook?) or
        #       is there another signal that can be sent to remove it from view, as PostDestroyer does not seem
        #       to do that.
        #

        #Rails.logger.error("sift_debug: Moderating Post")

        # Use the Discourse Flag Queue?
        # TODO: For now this assumes the user is going to use
        #   the default flag queue settings for visiblilty and
        #   moderation.  Have to do this right now, because the
        #   default behaviour of the Sift custom queue is to delete
        #   the post to hide it, and this screws up the default Flagged queue
        if SiteSetting.sift_use_standard_queue

          #Rails.logger.debug("sift_debug: Flagging Post  post: #{post.inspect}")
          #Rails.logger.debug("sift_debug:   active flags: #{post.active_flags.inspect}")

          flag_post_as(post, Discourse.system_user, result.topic_string)          

          # Should we add an extra flags
          SiteSetting.sift_extra_flag_users.split(',').each do |name|
            stripped_name = name.strip
            next if stripped_name.blank?
            next unless flag_user = User.find_by_username(stripped_name) 
            
            flag_post_as(post, flag_user, result.topic_string)
          end
        elsif !SiteSetting.sift_post_stay_visible
          # Should post be hidden/deleted until moderation?
          remove_post_and_notify(post, 'sift_human_moderation')
        end

        enqueue_sift_reviewable(post) if reviewable_api_enabled?

        # Mark Post For Requires Moderation
        DiscourseSift.move_to_state(post, 'requires_moderation')

        # Trigger an event that community sift has an item for human moderators. This allows moderators to notify chat rooms
        DiscourseEvent.trigger(:sift_post_failed_policy_guide)
      end
    end
  end

  def self.stats
    result = PostCustomField.where(name: 'SIFT_STATE').group(:value).count.symbolize_keys!
    result[:auto_moderated] ||= 0
    result[:requires_moderation] ||= 0
    result[:confirmed_failed] ||= 0
    result[:confirmed_passed] ||= 0
    result[:pass_policy_guide] ||= 0
    result[:classified] = result[:auto_moderated] + result[:requires_moderation] + result[:confirmed_failed] + result[:confirmed_passed] + result[:pass_policy_guide]
    result
  end

  def self.requires_moderation
    post_ids = PostCustomField.where(name: 'SIFT_STATE', value: 'requires_moderation').pluck(:post_id)
    Post.with_deleted.where(id: post_ids).includes(:topic, :user).references(:topic)
  end

  def self.move_to_state(post, state, opts = nil)
    opts ||= {}

    return if post.blank? || SiteSetting.sift_use_standard_queue || SiteSetting.sift_api_key.blank?

    post.custom_fields['SIFT_STATE'] = state

    post.save_custom_fields

    msg = { sift_review_count: DiscourseSift.requires_moderation.count }
    MessageBus.publish('/sift_counts', msg, user_ids: User.staff.pluck(:id))

  end

  # These methods are private. Do not call them directly
  def self.reviewable_api_enabled?
    defined?(ReviewableSiftPost)
  end

  def self.flag_post_as(post, user, topic_string)
    # TODO: Can't get newline to render by default.  Might need to investigate overriding template or custom template?
    # message: I18n.t('sift_flag_message') + "</br>\n" + result.topic_string
    message = I18n.t('sift_flag_message') + topic_string
    
    if reviewable_api_enabled? 
      PostActionCreator.create(user, post, :inappropriate, message: message)
    else
      post_action_type = PostActionType.types[:inappropriate]
      PostAction.act(user, post, post_action_type, message: message)
    end
  rescue PostAction::AlreadyActed
    nil # Post already flagged for this user
  rescue Exception => e
    Rails.logger.error("sift_debug: Exception when trying flag as system user: #{e.inspect}")
  end

  def self.remove_post_and_notify(post, reason)
    # Post Removed Due To Content
    PostDestroyer.new(Discourse.system_user, post).destroy

    # TODO: Maybe a different message if post sent to mod but still visible?
    # Notify User
    if SiteSetting.sift_notify_user
      SystemMessage.create(post.user, reason,topic_title: post.topic.title)
    end
  end

  def self.enqueue_sift_reviewable(post)
    system = Discourse.system_user
    reviewable = ReviewableSiftPost.needs_review!(
      created_by: system, target: post, topic: post.topic,
      reviewable_by_moderator: true, payload: { post_cooked: post.cooked }
    )

    reviewable.add_score(
      system, PostActionType.types[:inappropriate],
      created_at: reviewable.created_at
    )
  end
end