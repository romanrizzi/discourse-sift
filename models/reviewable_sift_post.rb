require_dependency 'reviewable'

class ReviewableSiftPost < Reviewable
  def post
    @post ||= (target || Post.with_deleted.find_by(id: target_id))
  end
end