Rails.application.routes.draw do
  # Disable PUT for now since rails sends these :update and they aren't really the same thing.
  def put(*_args); end

  routing_helper = Insights::API::Common::Routing.new(self)

  get '/health', :to => "status#health"

  prefix = "api"
  if ENV["PATH_PREFIX"].present? && ENV["APP_NAME"].present?
    prefix = File.join(ENV["PATH_PREFIX"], ENV["APP_NAME"]).gsub(/^\/+|\/+$/, "")
  end

  scope :as => :internal, :module => "internal", :path => "internal" do
    match "/v0/*path", :via => [:post], :to => redirect(:path => "/internal/v1.0/%{path}", :only_path => true)

    namespace :v1x0, :controller => 'notify', :path => "v1.0" do
      post '/notify/approval_request/:request_id', :action => 'notify_approval_request'
      post '/notify/task/:task_id', :action => 'notify_task'
    end
  end

  scope :as => :api, :module => "api", :path => prefix do
    routing_helper.redirect_major_version("v1.0", prefix)

    namespace :v1x0, :path => "v1.0" do
      concern :taggable do
        post      :tag,   :to => "tags#tag"
        post      :untag, :to => "tags#untag"
        resources :tags,  :controller => :tags, :only => [:index]
      end

      get "/openapi.json", :to => "root#openapi"
      post "/graphql" => "graphql#query"
      post '/orders/:order_id/submit_order', :to => "orders#submit_order", :as => 'order_submit_order'
      patch '/orders/:order_id/cancel', :to => "orders#cancel_order", :as => 'order_cancel'
      resources :orders,                :only => [:create, :index, :show, :destroy] do
        resources :order_items,           :only => [:create, :index, :show]

        post :restore, :to => "orders#restore"
      end
      resources :order_items, :only => [:index, :show, :destroy] do
        resources :progress_messages, :only => [:index]
        resources :approval_requests, :only => [:index]

        post :restore, :to => "order_items#restore"
      end
      post '/portfolios/:portfolio_id/share', :to => "portfolios#share", :as => 'share'
      post '/portfolios/:portfolio_id/unshare', :to => "portfolios#unshare", :as => 'unshare'
      get '/portfolios/:portfolio_id/share_info', :to => "portfolios#share_info", :as => 'share_info'
      resources :portfolios, :only => [:create, :destroy, :index, :show, :update], :concerns => [:taggable] do
        resources :portfolio_items,       :only => [:index]
        post :copy, :to => "portfolios#copy"
        post :undelete, :to => "portfolios#restore"
        get :icon, :to => 'icons#raw_icon'
      end
      resources :portfolio_items, :only => [:create, :destroy, :index, :show, :update], :concerns => [:taggable] do
        resources :provider_control_parameters, :only => [:index]
        resources :service_plans,               :only => [:index]
        get :icon, :to => 'icons#raw_icon'
        get :next_name, :action => 'next_name', :controller => 'portfolio_items'
        post :copy, :action => 'copy', :controller => 'portfolio_items'
        post :undelete, :action => 'undestroy', :controller => 'portfolio_items'
      end
      resources :icons, :only => [:create, :destroy, :show, :update] do
        get :icon_data, :to => 'icons#raw_icon'
      end
      resources :settings
      resources :tags, :only => [:index]
      resources :tenants, :only => [:index, :show] do
        post 'seed', :to => 'tenants#seed'
      end
      resources :service_plans, :only => [:create, :show] do
        get 'base', :to => 'service_plans#base'
        get 'modified', :to => 'service_plans#modified'
        patch 'modified', :to => 'service_plans#update_modified'
        post :reset, :to => 'service_plans#reset'
      end
    end
  end
end
