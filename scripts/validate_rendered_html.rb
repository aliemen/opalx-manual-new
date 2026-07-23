#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "pathname"
require "uri"
require "yaml"

ROOT = Pathname.new(__dir__).parent.expand_path
SITE = ROOT / "_site"
PROFILE = ENV.fetch("QUARTO_PROFILE", "opalx")
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
errors << "render does not contain the field-solver sidebar manifest" unless combined_html.include?("page-toc:field-solver")
errors << "render does not contain the elements sidebar manifest" unless combined_html.include?("page-toc:elements")
errors << "render does not contain the regression-test source URL" unless combined_html.include?("https://github.com/OPALX-project/regression-tests-x/blob/master")

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
  errors << "distribution sidebar lacks an accessible type toggle" unless distribution_html.include?("Toggle DISTRIBUTION types")
  errors << "distribution sidebar state keys are not rendered" unless distribution_html.include?("dataset.opalxStateKey")
else
  errors << "render is missing user-guide/beam-distributions.html"
end

field_solver_html_path = SITE / "user-guide/field-solver/index.html"
if field_solver_html_path.file?
  field_solver_html = File.read(field_solver_html_path)
  field_solver_anchors = %w[
    solver-backends solver-none solver-fft solver-open solver-cg fieldsolver-parameters
    mesh-pic-cycle boundary-conditions open-periodic-boundaries generic-dirichlet-boundaries
    space-charge-modes monolithic-mode binned-mode explicit-image-charges
    shifted-greens-correction compatibility-selection accuracy-cost
  ]
  field_solver_anchors.each do |anchor|
    errors << "field-solver render is missing ##{anchor}" unless field_solver_html.match?(/\bid=["']#{Regexp.escape(anchor)}["']/)
  end
  {
    "solver-backends" => /data-number=["']\d+\.1["']/,
    "solver-none" => /data-number=["']\d+\.1\.1["']/,
    "solver-cg" => /data-number=["']\d+\.1\.4["']/,
    "fieldsolver-parameters" => /data-number=["']\d+\.2["']/,
    "generic-dirichlet-boundaries" => /data-number=["']\d+\.4\.2["']/,
    "shifted-greens-correction" => /data-number=["']\d+\.5\.4["']/,
    "accuracy-cost" => /data-number=["']\d+\.7["']/
  }.each do |anchor, numbering|
    section = field_solver_html[/<section\s+id=["']#{Regexp.escape(anchor)}["'][\s\S]*?<\/section>/]
    errors << "field-solver ##{anchor} has incorrect automatic numbering" unless section&.match?(numbering)
  end
  errors << "field-solver does not suppress its duplicate margin TOC" unless field_solver_html.include?("opalx-sidebar-page-toc")
  errors << "field-solver sidebar lacks an accessible chapter toggle" unless field_solver_html.include?("Toggle Field Solver sections")
  errors << "field-solver sidebar lacks an accessible solver-type toggle" unless field_solver_html.include?("Toggle solver types")
  errors << "field-solver sidebar lacks accessible subsection toggles" unless field_solver_html.include?("Toggle ${item.text} subsections")
  %w[
    page-toc:field-solver page-toc:field-solver:backends
    page-toc:field-solver:boundaries page-toc:field-solver:modes
  ].each do |state_key|
    errors << "field-solver sidebar is missing state key #{state_key}" unless field_solver_html.include?(state_key)
  end
else
  errors << "render is missing user-guide/field-solver/index.html"
end

elements_html_path = SITE / "user-guide/elements.html"
if elements_html_path.file?
  elements_html = File.read(elements_html_path)
  element_anchors = %w[
    common-element-syntax drift constant-electric-field-cavity quadrupole multipole multipolet
    solenoid rfcavity travelingwave element-limitations
  ]
  element_anchors.each do |anchor|
    errors << "elements render is missing ##{anchor}" unless elements_html.match?(/\bid=["']#{Regexp.escape(anchor)}["']/)
  end
  {
    "common-element-syntax" => /data-number=["']\d+\.1["']/,
    "drift" => /data-number=["']\d+\.2["']/,
    "constant-electric-field-cavity" => /data-number=["']\d+\.3["']/,
    "rfcavity" => /data-number=["']\d+\.8["']/,
    "travelingwave" => /data-number=["']\d+\.9["']/,
    "element-limitations" => /data-number=["']\d+\.10["']/
  }.each do |anchor, numbering|
    section = elements_html[/<section\s+id=["']#{Regexp.escape(anchor)}["'][\s\S]*?<\/section>/]
    errors << "elements ##{anchor} has incorrect automatic numbering" unless section&.match?(numbering)
  end
  errors << "elements does not suppress its duplicate margin TOC" unless elements_html.include?("opalx-sidebar-page-toc")
  errors << "elements sidebar lacks an accessible chapter toggle" unless elements_html.include?("Toggle Elements sections")
  errors << "elements sidebar state key is not rendered" unless elements_html.include?("page-toc:elements")
else
  errors << "render is missing user-guide/elements.html"
end

worked_inputs_html_path = SITE / "getting-started/worked-inputs.html"
if worked_inputs_html_path.file?
  worked_inputs_html = File.read(worked_inputs_html_path)
  {
    "example-drift" => /data-number=["']\d+\.1["']/,
    "example-rfcavity" => /data-number=["']\d+\.2["']/,
    "example-space-charge" => /data-number=["']\d+\.3["']/
  }.each do |anchor, numbering|
    section = worked_inputs_html[/<section\s+id=["']#{Regexp.escape(anchor)}["'][\s\S]*?<\/section>/]
    errors << "worked-inputs ##{anchor} has incorrect automatic numbering" unless section&.match?(numbering)
  end
else
  errors << "render is missing getting-started/worked-inputs.html"
end

input_language_html_path = SITE / "user-guide/input-language.html"
if input_language_html_path.file?
  input_language_html = File.read(input_language_html_path)
  %w[
    simulation-at-a-glance core-syntax parser-native-structures simulation-definitions
    beamline-definitions time-dependence-definitions tracking-block-structures executable-actions
    execution-order
  ].each do |anchor|
    errors << "input-language render is missing ##{anchor}" unless input_language_html.match?(/\bid=["']#{Regexp.escape(anchor)}["']/)
  end
  errors << "input-language render is missing its overview cards" unless input_language_html.include?("doc-grid")
else
  errors << "render is missing user-guide/input-language.html"
end

physics_field_solver_html_path = SITE / "physics/field-solver/index.html"
if physics_field_solver_html_path.file?
  physics_field_solver_html = File.read(physics_field_solver_html_path)
  %w[
    field-solver-scope governing-electrostatic-model particle-mesh-discretization
    frames-transformations physics-boundary-conditions solver-formulations
    physics-binned-space-charge physics-emission-boundaries numerical-accuracy-convergence
    domain-decomposition field-solver-architecture field-solver-verification field-solver-limitations
  ].each do |anchor|
    errors << "physics field-solver render is missing ##{anchor}" unless physics_field_solver_html.match?(/\bid=["']#{Regexp.escape(anchor)}["']/)
  end
  errors << "physics field-solver HTML is missing its PNG diagram" unless physics_field_solver_html.include?("current-space-charge-class-diagram.png")
else
  errors << "render is missing physics/field-solver/index.html"
end

reports_html_path = SITE / "resources/presentations-reports.html"
if reports_html_path.file?
  reports_html = File.read(reports_html_path)
  year_section = reports_html[/<section\s+id=["']reports-2026["'][^>]*>/]
  errors << "Presentations and Reports render is missing the 2026 section" unless year_section
  errors << "Presentations and Reports still numbers the 2026 section" if year_section&.include?("data-number=")
else
  errors << "render is missing resources/presentations-reports.html"
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
  errors << "structures sidebar does not label subsection 1 as Binning" unless structures_html.include?('text: "Binning"')
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
