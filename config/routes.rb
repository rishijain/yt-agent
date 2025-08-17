Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Video transcript API
  get "videos/:video_id/transcript/:language", to: "videos#transcript"
  get "videos/:video_id/transcript", to: "videos#transcript"

  # Video chapters API
  get "videos/:video_id/chapters/:language", to: "videos#chapters"
  get "videos/:video_id/chapters", to: "videos#chapters"

  # Video download audio background job APIs
  post "videos/download-audio", to: "videos#enqueue_download"
  get "videos/download-audio/:job_id/status", to: "videos#download_status"

  # Defines the root path route ("/")
  # root "posts#index"
end
