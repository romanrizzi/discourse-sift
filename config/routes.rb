DiscourseSift::Engine.routes.draw do
  resource :sift_mod_queue, path: "/mod", constraints: StaffConstraint.new, only: [:index] do
    collection do
      post   "confirm_failed" => "sift_mod_queue#confirm_failed"
      post   "disagree_due_to_false_positive"        => "sift_mod_queue#disagree_due_to_false_positive"
      post   "disagree_due_to_too_strict"        => "sift_mod_queue#disagree_due_to_too_strict"
      post   "disagree_due_to_user_edited"        => "sift_mod_queue#disagree_due_to_user_edited"
      post   "disagree_due_to_other"        => "sift_mod_queue#disagree_due_to_other"
    end
  end
  resource :admin_mod_queue, path: "/", constraints: StaffConstraint.new, only: [:index] do
    collection do
      get    "/"            => "admin_mod_queue#index"
      get    "index"        => "admin_mod_queue#index"
      post   "confirm_failed" => "admin_mod_queue#confirm_failed"
      post   "allow"        => "admin_mod_queue#allow"
      post   "dismiss"      => "admin_mod_queue#dismiss"
    end
  end
end
