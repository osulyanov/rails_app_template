# Gems

use_auth = yes?("Use devise and cancan?")
if use_auth
  gem 'devise'
  gem "cancan"
  gem 'role_model', github: 'martinrehfeld/role_model'
end

if yes?("Use social auth?")
  gem 'omniauth'
  gem 'omniauth-facebook'
  gem 'omniauth-vkontakte'
end

case ask("Choose Template Engine (erb haml slim):", :limited_to => %w[erb haml slim])
  when "haml"
    gem "haml-rails"
  when "slim"
    gem "slim-rails"
  when "erb"
end

use_uploads = yes?("With files & images upload?")
if use_uploads
  gem 'carrierwave'
  gem 'mini_magick'
  gem 'fog', '~> 1.3.1'
  gem 'remotipart', '~> 1.2'
end

gem 'js-routes'
gem "simple_form", git: "https://github.com/plataformatec/simple_form"

deploy_to = ask("Deploy to (heroku unicorn)", limited_to: %w(heroku unicorn))

gem_group :development do
  gem "rspec-rails"
  gem "guard-rspec"

  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'bullet'

  if deploy_to == 'unicorn'
    gem 'capistrano'
    gem 'rvm-capistrano'
  end
end

gem_group :test do
  gem "rspec-rails"
  gem "capybara"
  gem "capybara-webkit"
  gem "launchy"
  gem "factory_girl_rails"
  gem "database_cleaner"
end

gem_group :production do
  case deploy_to
    when 'heroku'
      gem "rails_12factor"
    when 'unicorn'
      gem 'unicorn'
  end

  gem 'newrelic_rpm'
end

# Install gems
run "bundle install"

# Initialize simple form
generate "simple_form:install"

# Initialize RSpec
generate 'rspec:install'
# Configure RSpec
insert_into_file 'spec/spec_helper.rb',
                 "require 'capybara/rails'
require 'capybara/webkit/matchers'
Capybara.javascript_driver = :webkit
require 'factory_girl_rails'
require 'factory_girl_helpers'\n",
                 after: "require 'rspec/autorun'\n"

# Configure Devise
if use_auth
  generate 'devise:install'
  devise_model = ask("What Devise User model name?")
  devise_model = 'user' if devise_model.blank?
  generate 'devise', devise_model

  # Initialize CanCan
  generate 'cancan:ability'
end

# Index controller
generate :controller, 'index', 'index'
route "root to: 'index#index'"

# Migrate
rake "db:migrate"

# Configure Unicorn & Capistrano
if deploy_to == 'unicorn'
  # Unicorn


  # Capistrano
  run 'capify .'
end

# Configure uploads
if use_uploads
  # Carrierwave
  initializer 'carrierwave.rb', <<-CODE
CarrierWave.configure do |config|
  config.fog_credentials = {
      :provider => 'AWS', # required
      :aws_access_key_id => Rails.application.secrets.aws_key, # required
      :aws_secret_access_key => Rails.application.secrets.aws_secret, # required
      :region => 'eu-west-1', # optional, defaults to 'us-east-1'
      #:host => 's3.example.com', # optional, defaults to nil
      #:endpoint => 'https://s3.example.com:8080' # optional, defaults to nil
  }
  config.fog_directory = Rails.application.secrets.aws_bucket # required
  #config.fog_public = false # optional, defaults to true
  config.fog_attributes = {'Cache-Control' => 'max-age=315576000'} # optional, defaults to {}
end
  CODE
end

# .gitignore
run "cat << EOF >> .gitignore
*.rbc
capybara-*.html
.rspec
/log
/tmp
/db/*.sqlite3
/public/system
/coverage/
/spec/tmp
**.orig
rerun.txt
pickle-email-*.html
config/initializers/secret_token.rb
config/secrets.yml
/.bundle
/vendor/bundle
.rvmrc
/.idea
*.swp
.secret
.DS_Store
EOF"

# Git Initialize
git :init
git add: "."
git commit: "-a -m 'Initial commit'"

if yes?("Initialize GitHub repository?")
  git_uri = `git config remote.origin.url`.strip
  unless git_uri.size == 0
    say "Repository already exists:"
    say "#{git_uri}"
  else
    username = ask "What is your GitHub username?"
    run "curl -u #{username} -d '{\"name\":\"#{app_name}\"}' https://api.github.com/user/repos"
    git remote: %Q{ add origin git@github.com:#{username}/#{app_name}.git }
    git push: %Q{ origin master }
  end
end