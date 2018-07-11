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

  # TODO: Does this create a new client with every post?  Also means that using a persistent connection for
  # API requests is not possible.  Should probably use some caching?  Would need to make sure any caching can
  # handle setting changes.
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

      Rails.logger.error("sift_debug: classify_post after submit: #{result.inspect}")
      
      if !result.response && result.over_any_max_risk  #Fails policy auto denied

        #Rails.logger.error("sift_debug: Autodeleting Post")

        # Post Removed Due To Content
        PostDestroyer.new(Discourse.system_user, post).destroy

        # Mark Post As Auto Moderated Queue
        DiscourseSift.move_to_state(post, 'auto_moderated')

        # Notify User
        if SiteSetting.sift_notify_user
          SystemMessage.new(post.user).create(
            'sift_auto_filtered',
            topic_title: post.topic.title
          )
        end

        # Trigger an event that community sift auto moderated a post. This allows moderators to notify chat rooms
        DiscourseEvent.trigger(:sift_auto_moderated)

      elsif !result.response  #Fails policy guide and escalated to human moderation
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
          PostAction.act(
            Discourse.system_user,
            post,
            PostActionType.types[:notify_moderators],

            # TODO: Can't get newline to render by default.  Might need to investigate overriding template or custom template?
            #message: I18n.t('sift_flag_message') + "</br>\n" + result.topic_string
            message: I18n.t('sift_flag_message') + result.topic_string
          )

        else
          # Should post be hidden/deleted until moderation?
          if !SiteSetting.sift_post_stay_visible
            # Post Removed Due To Content
            PostDestroyer.new(Discourse.system_user, post).destroy

            # TODO: Maybe a different message if post sent to mod but still visible?
            #Notify User
            if SiteSetting.sift_notify_user
              SystemMessage.new(post.user).create(
                'sift_human_moderation',
                topic_title: post.topic.title
              )
            end
          end

          # Mark Post For Requires Moderation
          DiscourseSift.move_to_state(post, 'requires_moderation')

          # Trigger an event that community sift has an item for human moderators. This allows moderators to notify chat rooms
          DiscourseEvent.trigger(:sift_post_failed_policy_guide)

        end

      else

        #Rails.logger.error("sift_debug: Post passes.  post: #{post.inspect}")
        
        # Make post as passed policy guide
        DiscourseSift.move_to_state(post, 'pass_policy_guide')

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
    return if post.blank? || SiteSetting.sift_api_key.blank?

    post.custom_fields['SIFT_STATE'] = state

    post.save_custom_fields

    msg = { sift_review_count: DiscourseSift.requires_moderation.count }
    MessageBus.publish('/sift_counts', msg, user_ids: User.staff.pluck(:id))

  end

end
