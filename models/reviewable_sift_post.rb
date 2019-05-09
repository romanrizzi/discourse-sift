require_dependency 'reviewable'

class ReviewableSiftPost < Reviewable
  def post
    @post ||= (target || Post.with_deleted.find_by(id: target_id))
  end

  def build_actions(actions, guardian, _args)
    return [] unless pending?

    build_action(actions, :confirm_failed, icon: 'check', key: 'confirm_fails_policy')
    build_action(actions, :allow, icon: 'thumbs-up', key: 'confirm_passes_policy')
    build_action(actions, :ignore, icon: 'times', key: 'dismiss')
  end

  def perform_confirm_failed(performed_by, _args)
    # If post has not been deleted (i.e. if setting is on)
    # Then delete it now
    if post.deleted_at.blank?
      PostDestroyer.new(performed_by, post).destroy

      if SiteSetting.sift_notify_user
        SystemMessage.create(
          post.user,
          'sift_has_moderated',
          topic_title: post.topic.title
        )
      end
    end

    log_confirmation performed_by, 'confirmed_failed'
    successful_transition :approved, :agreed
  end

  def perform_allow(performed_by, _args)
    # It's possible the post was recovered already
    PostDestroyer.new(performed_by, post).recover if post.deleted_at

    log_confirmation(performed_by, 'confirmed_passed')
    successful_transition :rejected, :disagreed
  end

  def perform_ignore(performed_by, _args)
    log_confirmation(performed_by, 'dismissed')
    successful_transition :ignored, :ignored
  end

  private

  def build_action(actions, id, icon:, bundle: nil, key:)
    actions.add(id, bundle: bundle) do |action|
      action.icon = icon
      action.label = "js.sift.#{key}"
    end
  end

  def successful_transition(to_state, update_flag_status, recalculate_score: true)
    create_result(:success, to_state)  do |result|
      result.recalculate_score = recalculate_score
      result.update_flag_stats = { status: update_flag_status, user_ids: [created_by_id] }
    end
  end

  def log_confirmation(performed_by, custom_type)
    StaffActionLogger.new(performed_by).log_custom(custom_type,
      post_id: post.id, topic_id: post.topic_id
    )
  end
end
