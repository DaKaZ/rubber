source "https://rubygems.org"

gem 'jruby-openssl', :platform => :jruby
gem 'unlimited-strength-crypto', :platform => :jruby

group :development do
  gem 'fog-aws'
  gem 'fog-digitalocean', git: 'https://github.com/nirvdrum/fog-digitalocean.git', branch: 'fix-list_images-pagination'
  gem 'fog-vsphere'
  gem 'mime-types'
end

# Specify your gem's dependencies in rubber.gemspec
gemspec
