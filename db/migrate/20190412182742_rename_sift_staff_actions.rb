class RenameSiftStaffActions < ActiveRecord::Migration[5.2]
  def up
    DB.exec <<~SQL
    UPDATE user_histories AS uh
    SET custom_type = CASE
      WHEN uh.custom_type = 'confirmed_failed' THEN 'sift_confirmed_failed'
      WHEN uh.custom_type = 'confirmed_passed' THEN 'sift_confirmed_passed'
      ELSE 'sift_ignored'
    END
    FROM post_custom_fields AS pcf
    WHERE
      uh.action = #{UserHistory.actions[:custom_staff]} AND
      uh.post_id = pcf.post_id AND
      pcf.name = 'SIFT_STATE'
    SQL
  end

  def down
    DB.exec <<~SQL
    UPDATE user_histories AS uh
    SET custom_type = CASE
      WHEN uh.custom_type = 'sift_confirmed_failed' THEN 'confirmed_failed'
      WHEN uh.custom_type = 'sift_confirmed_passed' THEN 'confirmed_passed'
      ELSE 'dismissed'
    END
    FROM post_custom_fields AS pcf
    WHERE
      uh.action = #{UserHistory.actions[:custom_staff]} AND
      uh.post_id = pcf.post_id AND
      pcf.name = 'SIFT_STATE'
    SQL
  end
end
