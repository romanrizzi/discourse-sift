DiscourseSift::Engine.routes.draw do
  resource :sift_mod_queue, path: "/mod", constraints: StaffConstraint.new, only: [:index] do
    collection do
      post   "confirm_failed" => "sift_mod_queue#confirm_failed"
      post   "disagree"        => "sift_mod_queue#disagree"
      post   "disagree_other"        => "sift_mod_queue#disagree_other"
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
