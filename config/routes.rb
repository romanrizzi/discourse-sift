DiscourseSift::Engine.routes.draw do
  resource :admin_mod_queue, path: "/", constraints: StaffConstraint.new, only: [:index] do
    collection do
      get    "/"            => "admin_mod_queue#index"
      get    "index"        => "admin_mod_queue#index"
      post   "confirm_failed" => "admin_mod_queue#confirm_failed"
      post   "allow"        => "admin_mod_queue#allow"
      post   "dismiss"      => "admin_mod_queue#dismiss"
      post   "silence"      => "admin_mod_queue#silence"
      post   "suspend"      => "admin_mod_queue#suspend"
    end
  end
end
