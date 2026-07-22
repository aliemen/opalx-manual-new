#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "pathname"
require "uri"
require "yaml"

ROOT = Pathname.new(__dir__).parent.expand_path
SITE = ROOT / "_site"
PROFILE = ENV.fetch("QUARTO_PROFILE", "personal")
PROFILE_FILE = ROOT / "_quarto-#{PROFILE}.yml"

abort "error: rendered site is missing: #{SITE}" unless SITE.directory?
abort "error: unknown Quarto profile: #{PROFILE}" unless PROFILE_FILE.file?

profile = YAML.safe_load(File.read(PROFILE_FILE), permitted_classes: [], aliases: false)
expected_documents = profile.fetch("documents-base-url")
expected_repository = profile.fetch("manual-repository-url")
html_files = SITE.glob("**/*.html")
combined_html = html_files.map { |path| File.read(path) }.join("\n")

errors = []
errors << "render does not contain the profile's document base URL" unless combined_html.include?(expected_documents)
errors << "render does not contain the profile's manual repository URL" unless combined_html.include?(expected_repository)
errors << "render does not contain Quarto's color-scheme persistence" unless combined_html.include?("quarto-color-scheme")
errors << "render does not contain OPALX sidebar-state persistence" unless combined_html.include?("opalx-sidebar-state-v1")

html_cache = {}

manual_html_files = html_files.reject { |path| path.to_s.start_with?("#{SITE}/api/") }

manual_html_files.each do |source|
  html = File.read(source)
  hrefs = html.scan(/\bhref\s*=\s*["']([^"']+)["']/i).flatten.map { |href| CGI.unescapeHTML(href) }

  hrefs.each do |href|
    next if href.empty? || href.start_with?("mailto:", "javascript:", "data:", "//")
    next if href.match?(/\A[a-z][a-z0-9+.-]*:/i)

    path_part, fragment = href.split("#", 2)
    path_part = path_part.to_s.split("?", 2).first.to_s
    target = if path_part.empty?
               source
             elsif path_part.start_with?("/")
               SITE / path_part.delete_prefix("/")
             else
               source.dirname / path_part
             end

    target = Pathname.new(target.to_s).cleanpath
    target = target / "index.html" if target.directory?
    target = Pathname.new("#{target}.html") if !target.exist? && target.extname.empty?

    unless target.to_s.start_with?("#{SITE}/") && target.file?
      errors << "#{source.relative_path_from(SITE)}: missing local target #{href}"
      next
    end

    next if fragment.nil? || fragment.empty? || target.extname.downcase != ".html"

    decoded_fragment = URI.decode_www_form_component(fragment)
    target_html = html_cache[target] ||= File.read(target)
    escaped = Regexp.escape(decoded_fragment)
    unless target_html.match?(/\b(?:id|name)\s*=\s*["']#{escaped}["']/i)
      errors << "#{source.relative_path_from(SITE)}: missing fragment ##{decoded_fragment} in #{target.relative_path_from(SITE)}"
    end
  end
end

unless errors.empty?
  errors.uniq.sort.each { |message| warn "error: #{message}" }
  abort "render validation failed with #{errors.uniq.length} error(s)"
end

puts "validated #{manual_html_files.length} rendered manual pages for the #{PROFILE} profile"
