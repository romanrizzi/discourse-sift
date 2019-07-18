desc 'Migrate sift reviews to the new Reviewable API'
task 'reviewables:migrate_sift_reviews' => :environment do
  migrate_reviewables
  migrate_creation_history
  migrate_scores
  migrate_resolution_history
end

def migrate_reviewables
  reporter = Discourse.system_user
  DB.exec <<~SQL
    INSERT INTO reviewables(
      type,
      status,
      created_by_id,
      reviewable_by_moderator,
      payload,
      category_id,
      topic_id,
      potential_spam,
      target_id,
      target_type,
      target_created_by_id,
      created_at,
      updated_at
    )
    SELECT
      'ReviewableSiftPost',
      CASE
        WHEN pcf.value = 'confirmed_failed' THEN #{Reviewable.statuses[:approved]}
        WHEN pcf.value = 'confirmed_passed' THEN #{Reviewable.statuses[:rejected]}
        WHEN pcf.value = 'dismissed' THEN #{Reviewable.statuses[:ignored]}
        ELSE #{Reviewable.statuses[:pending]}
      END,
      #{reporter.id},
      TRUE,
      json_build_object('post_cooked', p.cooked, 'sift', sift.value),
      t.category_id,
      p.topic_id,
      TRUE,
      pcf.post_id,
      'Post',
      p.user_id,
      pcf.created_at,
      pcf.updated_at
    FROM post_custom_fields AS pcf
    INNER JOIN posts AS p ON pcf.post_id = p.id
    INNER JOIN topics AS t ON t.id = p.topic_id
    INNER JOIN post_custom_fields AS sift ON sift.post_id = p.id AND sift.name = 'sift'
    WHERE
      pcf.name = 'SIFT_STATE' AND
      pcf.value IN ('confirmed_failed', 'confirmed_passed', 'dismissed', 'requires_moderation')
  SQL
end

def migrate_scores
  DB.exec <<~SQL
    INSERT INTO reviewable_scores (
      reviewable_id,
      user_id,
      reviewable_score_type,
      status,
      score,
      take_action_bonus,
      created_at,
      updated_at,
      reviewed_by_id,
      reviewed_at
    )
    SELECT
      r.id,
      r.created_by_id,
      #{PostActionType.types[:inappropriate]},
      CASE
        WHEN r.status = 1 OR r.status = 4 THEN 1
        ELSE r.status
      END,
      1.0 +
      CASE
        WHEN u.admin = TRUE OR u.moderator = TRUE THEN 5.0
        ELSE u.trust_level
      END +
      CASE
        WHEN (us.flags_agreed + us.flags_disagreed + us.flags_ignored) > 5
        THEN (us.flags_agreed / (us.flags_agreed + us.flags_disagreed + us.flags_ignored)) * 5
        ELSE 0.0
      END +
      CASE WHEN r.status <> 0 THEN 5.0 ELSE 0.0 END,
      CASE WHEN r.status <> 0 THEN 5.0 ELSE 0.0 END,
      r.created_at,
      r.created_at,
      uh.acting_user_id,
      uh.created_at
    FROM reviewables AS r
    INNER JOIN users AS u ON r.created_by_id = u.id
    LEFT JOIN user_stats AS us ON  us.user_id = u.id
    LEFT JOIN user_histories AS uh ON uh.post_id = r.target_id AND
      uh.custom_type IN ('confirmed_failed','confirmed_passed','dismissed')
    WHERE r.type = 'ReviewableSiftPost'
  SQL
end

def migrate_creation_history
  DB.exec <<~SQL
    INSERT INTO reviewable_histories (
      reviewable_id,
      reviewable_history_type,
      status,
      created_by_id,
      created_at,
      updated_at
    )
    SELECT
      r.id,
      #{ReviewableHistory.types[:created]},
      #{Reviewable.statuses[:ignored]},
      r.created_by_id,
      r.created_at,
      r.created_at
    FROM reviewables AS r
    WHERE r.type = 'ReviewableSiftPost'
  SQL
end

def migrate_resolution_history
  DB.exec <<~SQL
    INSERT INTO reviewable_histories (
      reviewable_id,
      reviewable_history_type,
      status,
      created_by_id,
      created_at,
      updated_at
    )
    SELECT
      r.id,
      #{ReviewableHistory.types[:transitioned]},
      CASE
        WHEN uh.custom_type = 'confirmed_failed' THEN #{Reviewable.statuses[:approved]}
        WHEN uh.custom_type = 'confirmed_passed' THEN #{Reviewable.statuses[:rejected]}
        ELSE #{Reviewable.statuses[:ignored]}
      END,
      uh.acting_user_id,
      r.updated_at,
      r.updated_at
    FROM reviewables AS r
    INNER JOIN user_histories AS uh ON uh.post_id = r.target_id
    WHERE
      uh.custom_type IN ('confirmed_failed', 'confirmed_passed', 'dismissed') AND
      r.type = 'ReviewableSiftPost'
  SQL
end
