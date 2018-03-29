require "fileutils"
require "shellwords"

# Copied from: https://github.com/mattbrictson/rails-template
# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("jumpstart-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/mattrothstein/jumpstart.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{jumpstart/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def add_gems
  gem 'haml'
  gem 'haml-rails'
  gem 'data-confirm-modal', '~> 1.6.2'
  gem 'devise', '~> 4.4.3'
  gem 'devise-bootstrapped', github: 'excid3/devise-bootstrapped', branch: 'bootstrap4'
  gem 'font-awesome-sass', '~> 4.7'
  gem 'gravatar_image_tag', github: 'mdeering/gravatar_image_tag'
  gem 'jquery-rails', '~> 4.3.1'
  gem 'bootstrap', '~> 4.0.0.beta'
  gem 'mini_magick', '~> 4.8'
end

def set_application_name
  # Add Application Name to Config
  environment "config.application_name = Rails.application.class.parent_name"

  # Announce the user where he can change the application name in the future.
  puts "You can change application name inside: ./config/application.rb"
end

def add_users
  # Install Devise
  generate "devise:install"

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'
  route "root to: 'home#index'"

  # Devise notices are installed via Bootstrap
  generate "devise:views:bootstrapped"

  # Create Devise User
  generate :devise, "User",
           "name",
           "announcements_last_read_at:datetime",
           "admin:boolean"

  # Set admin default to false
  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end

  requirement = Gem::Requirement.new("> 5.2")
  rails_version = Gem::Version.new(Rails::VERSION::STRING)

  if requirement.satisfied_by? rails_version
    gsub_file "config/initializers/devise.rb",
      /  # config.secret_key = .+/,
      "  config.secret_key = Rails.application.credentials.secret_key_base"
  end
end

def add_bootstrap
  # Remove Application CSS
  run "rm app/assets/stylesheets/application.css"

  # Add Bootstrap JS
  insert_into_file(
    "app/assets/javascripts/application.js",
    "\n//= require jquery\n//= require popper\n//= require bootstrap\n//= require data-confirm-modal",
    after: "//= require rails-ujs"
  )
end

def convert_to_haml
  run "rake haml:erb2haml"
end

def copy_templates
  directory "app", force: true
  directory "config", force: true
  directory "lib", force: true
end

# Main setup
add_template_repository_to_source_path

add_gems

after_bundle do
  set_application_name
  add_bootstrap
  convert_to_haml

  copy_templates

  # Migrate
  rails_command "db:create"
  rails_command "db:migrate"

  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
