require 'bundler/setup'
require 'jekyll'
require 'jekyll-contentful-data-import'

Dir[File.expand_path("lib/**/*.rb")].each { |file| require file }

namespace :build do
  desc "Run `jekyll build` with ACC configuration (use `foreman start acc` for `jekyll serve`)"
  task :acc do
    Jekyll::Commands::Build.process(config: ["_config.yml", "_config/acc.yml"])
  end

  desc "Run `jekyll build` with PEC configuration (use `foreman start pec` for `jekyll serve`)"
  task :pec do
    Jekyll::Commands::Build.process(config: ["_config.yml", "_config/pec.yml"])
  end

  desc "Run `jekyll build` with ACC staging configuration (use `foreman start acc_staging` for `jekyll serve`)"
  task :acc_staging do
    Jekyll::Commands::Build.process(config: ["_config.yml", "_config/acc_staging.yml"])
  end

  desc "Run `jekyll build` with PEC staging configuration (use `foreman start pec_staging` for `jekyll serve`)"
  task :pec_staging do
    Jekyll::Commands::Build.process(config: ["_config.yml", "_config/pec_staging.yml"])
  end
end

desc "Build all ACC and PEC sites"
task :build do
  if ENV["CI"] || system("which parallel") # On macOS: `brew install parallel` (optional)
    exec("parallel bundle exec rake build:{} ::: acc pec acc_staging pec_staging")
  else
    %w(acc pec acc_staging pec_staging).each { |site| Rake::Task["build:#{site}"].invoke }
  end
end

namespace :contentful do
  desc "Import ACC Contentful data"
  task :acc do
    config = Jekyll.configuration["contentful"]
    config["spaces"].select! { |space| space.include?("acc") }

    config["spaces"][0]["acc"].merge!({
      "space" => ENV["CONTENTFUL_ACC_SPACE_ID"],
      "access_token" => ENV["CONTENTFUL_ACC_ACCESS_TOKEN"]
    })

    Jekyll::Commands::Contentful.process([], {}, config)
  end

  desc "Import PEC Contentful data"
  task :pec do
    config = Jekyll.configuration["contentful"]
    config["spaces"].select! { |space| space.include?("pec") }

    config["spaces"][0]["pec"].merge!({
      "space" => ENV["CONTENTFUL_PEC_SPACE_ID"],
      "access_token" => ENV["CONTENTFUL_PEC_ACCESS_TOKEN"]
    })

    Jekyll::Commands::Contentful.process([], {}, config)
  end

  desc "Import ACC staging Contentful data"
  task :acc_staging do
    config = Jekyll.configuration["contentful"]
    config["spaces"].select! { |space| space.include?("acc_staging") }

    config["spaces"][0]["acc_staging"].merge!({
                                          "space" => ENV["CONTENTFUL_ACC_STAGING_SPACE_ID"],
                                          "access_token" => ENV["CONTENTFUL_ACC_STAGING_ACCESS_TOKEN"]
                                      })

    Jekyll::Commands::Contentful.process([], {}, config)
  end

  desc "Import PEC staging Contentful data"
  task :pec_staging do
    config = Jekyll.configuration["contentful"]
    config["spaces"].select! { |space| space.include?("pec_staging") }

    config["spaces"][0]["pec_staging"].merge!({
                                          "space" => ENV["CONTENTFUL_PEC_STAGING_SPACE_ID"],
                                          "access_token" => ENV["CONTENTFUL_PEC_STAGING_ACCESS_TOKEN"]
                                      })

    Jekyll::Commands::Contentful.process([], {}, config)
  end
end

desc "Import both ACC and PEC Contentful data"
multitask :contentful => ["contentful:acc", "contentful:pec"]

desc "Import ACC and PEC event listings from Socrata (data.austintexas.gov)"
task :calendar do
  Calendar::Import.import(Jekyll.configuration)
end

desc "Import all Contentful and Calendar data"
multitask :import => [:contentful, :calendar]

namespace :deploy do
  task :acc do
    exec "SITE=acc S3_BUCKET=test-acc.prod s3_website push --site=_site/acc"
  end

  task :pec do
    exec "SITE=pec S3_BUCKET=test-pec.prod s3_website push --site=_site/pec"
  end

  task :acc_stage do
    exec "SITE=acc_staging S3_BUCKET=test-acc.stage s3_website push --site=_site/acc_staging"
  end

  task :pec_stage do
    exec "SITE=pec_staging S3_BUCKET=test-pec.stage s3_website push --site=_site/pec_staging"
  end
end

task :deploy do
  exec "parallel bundle exec rake deploy:{} ::: acc pec acc_stage pec_stage"
end

# CI-specific import, build, and deploy commands that toggle between ACC, PEC, or both, depending on
# a $SITE env var, which is set as a build parameter by the Contentful webhooks. We build and deploy
# only the relevant site when receiving a Contentful webhook, but new commits to master update both.
namespace :ci do
  task :import => [:calendar] do
    Rake::Task["contentful"].invoke(ENV["SITE"])
  end

  task :build do
    task = ENV["SITE"] ? "build:#{ENV["SITE"]}" : "build"
    Rake::Task[task].invoke
  end

  task :deploy do
    task = ENV["SITE"] ? "deploy:#{ENV["SITE"]}" : "deploy"
    Rake::Task[task].invoke
  end

  # Nightly task run by Heroku Scheduler to rebuild the site (rebuilding nightly ensures the
  # calendar is always up-to-date).
  task :scheduler do
    require 'faraday'

    connection = Faraday.new("https://circleci.com") do |faraday|
      faraday.request  :url_encoded
      faraday.response :logger
      faraday.adapter Faraday.default_adapter
    end

    connection.post("/api/v1/project/numsweb/austinconventioncenter.com/tree/master") do |request|
      request.params["circle-token"] = ENV["CIRCLE_TOKEN"]
    end

    #build the staging content from the staging branch
    #connection.post("/api/v1/project/numsweb/austinconventioncenter.com/tree/staging") do |request|
    #  request.params["circle-token"] = ENV["CIRCLE_TOKEN"]
    #end
  end
end
