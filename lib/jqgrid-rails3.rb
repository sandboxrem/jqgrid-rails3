require "jqgrid-rails3/version"

module Jqgrid
  class Railtie < Rails::Railtie
    railtie_name :jqgrid-rails3

    rake_tasks do
      load 'tasks/2dc_jqgrid_tasks.rake'
    end
  end
end
