# frozen_string_literal: true

require_relative "lib/features/version"

Gem::Specification.new do |spec|
  spec.name = "features"
  spec.version = Features::VERSION
  spec.authors = ["simon.ryu"]
  spec.email = ["neocoin@gmail.com"]

  spec.summary = "issue tool"
  spec.description = "features help"
  spec.homepage = "https://github.com/ssfa/ssfa-tools"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["sourcㅓe_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "rainbow"
  spec.add_dependency "retryable"
  spec.add_dependency "thor"

  spec.add_development_dependency "rspec", "~> 3.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
