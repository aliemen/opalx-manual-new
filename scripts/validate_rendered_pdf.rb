#!/usr/bin/env ruby

require "open3"
require "pathname"

root = Pathname.new(__dir__).parent
pdf = root / "_site/OPALX-Documentation.pdf"
abort "error: rendered PDF is missing: #{pdf}" unless pdf.file?

text, text_error, text_status = Open3.capture3("pdftotext", "-layout", pdf.to_s, "-")
abort "error: pdftotext failed: #{text_error}" unless text_status.success?

chapter_match = text.match(/^[\f \t]*(\d+)[ \t]+Beam and Distributions[ \t]*$/)
abort "error: PDF does not contain the numbered Beam and Distributions chapter" unless chapter_match

chapter = chapter_match[1]
expected_headings = [
  ["#{chapter}.1", "EMISSIONSOURCE"],
  ["#{chapter}.2", "EMISSIONSOURCELIST"],
  ["#{chapter}.3", "DISTRIBUTION"],
  ["#{chapter}.3.1", "GAUSS"],
  ["#{chapter}.3.2", "MULTIVARIATEGAUSS"],
  ["#{chapter}.3.3", "FLATTOP"],
  ["#{chapter}.3.4", "OPALFLATTOP"],
  ["#{chapter}.3.5", "FROMFILE"],
  ["#{chapter}.3.6", "EMITTEDFROMFILE"],
  ["#{chapter}.4", "Reproducibility and current limitations"]
]

errors = []
expected_headings.each do |number, title|
  pattern = /^[\f \t]*#{Regexp.escape(number)}[ \t]+#{Regexp.escape(title)}[ \t]*$/
  errors << "missing PDF heading: #{number} #{title}" unless text.match?(pattern)
end

tracking_match = text.match(/^[\f \t]*(\d+)[ \t]+Tracking[ \t]*$/)
if tracking_match
  tracking_chapter = tracking_match[1]
  %w[TRACK RUN ENDTRACK].each_with_index do |title, index|
    number = "#{tracking_chapter}.#{index + 1}"
    errors << "missing PDF heading: #{number} #{title}" unless
      text.match?(/^[\f \t]*#{Regexp.escape(number)}[ \t]+#{title}[ \t]*$/)
  end
else
  errors << "PDF does not contain the numbered Tracking chapter"
end

{
  "static OPALX variant labels" => "OPALX",
  "static OPAL variant labels" => "OPAL",
  "retained OPAL distribution types" => "BINOMIAL",
  "retained OPAL field-solver material" => "Particle-Particle-Particle-Mesh",
  "User Guide Appendix A" => "Field Maps",
  "User Guide Appendix B" => "Language Syntax",
  "User Guide Appendix C" => "OPAL-MADX Conversion",
  "User Guide Appendix D" => "Auto-phasing"
}.each do |description, required_text|
  errors << "PDF is missing #{description}" unless text.include?(required_text)
end
if text.match?(/Documentation version\s+OPALX\s+OPAL\s+Both/)
  errors << "PDF unexpectedly contains the interactive selector control"
end

info, info_error, info_status = Open3.capture3("pdfinfo", pdf.to_s)
if !info_status.success?
  errors << "pdfinfo failed: #{info_error.strip}"
elsif !info.match?(/^Page size:.*\(A4\)$/)
  errors << "rendered PDF does not use A4 pages"
end

abort errors.map { |error| "error: #{error}" }.join("\n") unless errors.empty?

puts "validated A4 PDF numbering for Beam and Distributions chapter #{chapter}"
