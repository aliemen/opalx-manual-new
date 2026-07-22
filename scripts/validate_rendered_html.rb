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
errors << "render does not contain the distribution sidebar manifest" unless combined_html.include?("page-toc:beam-distributions")
errors << "render does not contain the structures sidebar manifest" unless combined_html.include?("page-toc:structures")

distribution_html_path = SITE / "user-guide/beam-distributions.html"
if distribution_html_path.file?
  distribution_html = File.read(distribution_html_path)
  distribution_anchors = %w[
    emissionsource emissionsourcelist distribution gauss multivariategauss flattop opalflattop
    fromfile emittedfromfile reproducibility-limitations
  ]
  distribution_anchors.each do |anchor|
    errors << "beam-distributions render is missing ##{anchor}" unless distribution_html.match?(/\bid=["']#{Regexp.escape(anchor)}["']/)
  end
  {
    "emissionsource" => /data-number=["']\d+\.1["']/,
    "emissionsourcelist" => /data-number=["']\d+\.2["']/,
    "distribution" => /data-number=["']\d+\.3["']/,
    "gauss" => /data-number=["']\d+\.3\.1["']/,
    "emittedfromfile" => /data-number=["']\d+\.3\.6["']/
  }.each do |anchor, numbering|
    section = distribution_html[/<section\s+id=["']#{Regexp.escape(anchor)}["'][\s\S]*?<\/section>/]
    errors << "beam-distributions ##{anchor} has incorrect automatic numbering" unless section&.match?(numbering)
  end
  errors << "beam-distributions does not suppress its duplicate margin TOC" unless distribution_html.include?("opalx-sidebar-page-toc")
  errors << "distribution sidebar lacks an accessible chapter toggle" unless distribution_html.include?("Toggle Beam and Distributions sections")
  errors << "distribution sidebar lacks an accessible type toggle" unless distribution_html.include?("Toggle ${item.text} types")
  errors << "distribution sidebar state keys are not rendered" unless distribution_html.include?("dataset.opalxStateKey")
else
  errors << "render is missing user-guide/beam-distributions.html"
end

structures_html_path = SITE / "user-guide/structures/index.html"
if structures_html_path.file?
  structures_html = File.read(structures_html_path)
  binning_section = structures_html[/<section\s+id=["']binning["'][\s\S]*?<\/section>/]
  errors << "structures render is missing #binning" unless binning_section
  errors << "BINNING has incorrect automatic numbering" unless binning_section&.match?(/data-number=["']\d+\.1["']/)
  errors << "structures does not suppress its duplicate margin TOC" unless structures_html.include?("opalx-sidebar-page-toc")
  errors << "structures sidebar lacks an accessible chapter toggle" unless structures_html.include?("Toggle Structures sections")
  errors << "structures sidebar state key is not rendered" unless structures_html.include?("page-toc:structures")
else
  errors << "render is missing user-guide/structures/index.html"
end

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
