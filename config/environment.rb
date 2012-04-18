# Load the rails application
require File.expand_path('../application', __FILE__)

# load module used to get current user for active recorde observer
require 'user_info'

# load omniauth strategies with database lookups api keys at runtime
require 'twitter_database'
require 'facebook_database'

# Initialize the rails application
Zammad::Application.initialize!
