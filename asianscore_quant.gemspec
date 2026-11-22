# frozen_string_literal: true

require_relative "lib/asianscore_quant/version"

Gem::Specification.new do |spec|
  spec.name = "asianscore_quant"
  spec.version = AsianscoreQuant::VERSION
  spec.authors = ["AsianScore Quantitative Research Lab"]
  spec.email = ["rubygems@aimail.men"]

  spec.summary = "Zero-dependency Ruby SDK for sports quantitative modeling & AsianScore live ledger"
  spec.description = "Zero-dependency Ruby quantitative sports analytics toolkit providing multiplicative and power odds devigging, fractional Kelly bankroll sizing, Dixon-Coles bivariate Poisson match probabilities, multi-class Brier score calibration, and a live AsianScore summary API client."
  spec.homepage = "https://asianscore.com/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri" => "https://asianscore.com/",
    "documentation_uri" => "https://asianscore.com/tools.html",
    "source_code_uri" => "https://github.com/AIYIXIU/asianscore-ruby",
    "changelog_uri" => "https://asianscore.com/models.html#ledger",
    "bug_tracker_uri" => "https://github.com/AIYIXIU/asianscore-ruby/issues"
  }

  spec.files = Dir.glob("{lib,test}/**/*").select { |f| File.file?(f) } + %w[README.md LICENSE asianscore_quant.gemspec]
  spec.require_paths = ["lib"]
end
