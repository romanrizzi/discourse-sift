# this index makes looking up posts requiring review much faster

class AddSiftCustomFieldIndex < ActiveRecord::Migration[5.1]
  def change
    add_index(
      :post_custom_fields,
      [:post_id],
      name: 'idx_post_custom_fields_sift',
      where: "name = 'SIFT_STATE' AND value = 'requires_moderation'"
    )
  end
end
