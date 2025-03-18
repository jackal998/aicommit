#!/usr/bin/env ruby

require 'bundler/setup'
require 'json'

# Exit if no file provided
if ARGV.empty?
  puts "Usage: ruby run_tests_with_coverage.rb path/to/spec_file.rb"
  exit 1
end

spec_file = File.expand_path(ARGV[0]) # Convert to absolute path if relative

# Validate spec file exists
unless File.exist?(spec_file)
  puts "Error: Spec file not found: #{spec_file}"
  exit 1
end

# Instead of starting SimpleCov here, we'll pass the COVERAGE env var to RSpec
puts "Running tests with: #{spec_file}"

# Run the tests in a way that will properly generate coverage
command = "COVERAGE=true bundle exec rspec #{spec_file}"
puts command
system(command, out: $stdout, err: :out)

# Give SimpleCov enough time to finish writing its results
sleep 1

# Parse coverage data
coverage_file = 'coverage/.resultset.json'
unless File.exist?(coverage_file)
  puts "No coverage data found at #{coverage_file}. Make sure SimpleCov is configured in your spec_helper.rb"
  exit 1
end

# Extract implementation file path from spec file path
impl_file_base = File.basename(spec_file, "_spec.rb")
impl_file_dir = spec_file.gsub("spec/", "lib/").gsub("_spec.rb", ".rb")
possible_impl_path = impl_file_dir

puts "Looking for implementation file with base name: #{impl_file_base}"
puts "Expected path might be: #{impl_file_dir}"

begin
  coverage_data = JSON.parse(File.read(coverage_file))

  # Debug information about the coverage data structure
  puts "\nCoverage data structure:"
  puts "Keys: #{coverage_data.keys}"

  # Verify we have coverage data
  if coverage_data.empty? || !coverage_data.keys.first || !coverage_data[coverage_data.keys.first]["coverage"] ||
     coverage_data[coverage_data.keys.first]["coverage"].empty?
    puts "The coverage data is empty. Make sure SimpleCov is properly configured in your spec_helper.rb"
    puts "Your spec_helper.rb should include:"
    puts "  require 'simplecov'"
    puts "  SimpleCov.start do"
    puts "    add_filter '/spec/'"
    puts "  end"
    exit 1
  end

  # Get the first result key (usually "RSpec")
  result_key = coverage_data.keys.first

  # Find implementation file in coverage data
  found_file = nil
  covered_files = coverage_data[result_key]["coverage"].keys

  puts "\nLooking for implementation file in #{covered_files.size} covered files:"

  # Try different approaches to find the implementation file
  covered_files.each do |file_path|
    puts "Checking: #{file_path}"
    # First try for exact match at end of path
    if file_path.end_with?("/#{impl_file_base}.rb")
      puts "✅ Found exact match!"
      found_file = file_path
      break
    # Then check if file_path contains the implementation filename
    elsif file_path.include?(impl_file_base + ".rb")
      puts "✅ Found partial match!"
      found_file = file_path
      break
    end
  end

  unless found_file
    puts "\nCould not find coverage data for implementation of #{spec_file}"
    puts "We were looking for a file containing: #{impl_file_base}.rb"
    puts "\nAvailable files in coverage:"
    covered_files.each { |f| puts "  - #{f}" }

    # Let's try a more flexible approach if we can't find the exact file
    puts "\nTrying a more flexible matching approach..."

    # Extract the most significant part of the filename
    # For example, from "ai_client_spec.rb" extract "ai_client"
    base_name_parts = impl_file_base.split('_')
    if base_name_parts.size > 1
      significant_name = base_name_parts.join('_')

      puts "Looking for any file containing: #{significant_name}"

      covered_files.each do |file_path|
        if file_path.include?(significant_name)
          puts "✅ Found file using flexible matching: #{file_path}"
          found_file = file_path
          break
        end
      end
    end

    # If still not found, let user choose from the list
    unless found_file
      puts "\nStill couldn't automatically find the implementation file."
      puts "Please enter the number of the file you want to analyze:"

      covered_files.each_with_index do |file, index|
        puts "#{index + 1}: #{file}"
      end

      print "Enter file number (or press Enter to exit): "
      choice = gets.chomp

      if choice.empty?
        puts "No file selected. Exiting."
        exit 0
      elsif choice.to_i.between?(1, covered_files.size)
        found_file = covered_files[choice.to_i - 1]
      else
        puts "Invalid selection. Exiting."
        exit 1
      end
    end
  end

  puts "\nAnalyzing coverage for: #{found_file}"

  # Analyze coverage for the found file
  lines_data = coverage_data[result_key]["coverage"][found_file]["lines"]

  puts "\n=== Coverage Report for #{found_file} ===\n\n"

  # Calculate coverage statistics
  total_lines = lines_data.count { |line| line != nil }
  covered_lines = lines_data.count { |line| line != nil && line > 0 }
  uncovered_lines = []

  lines_data.each_with_index do |cov, i|
    line_num = i + 1
    uncovered_lines << line_num if cov == 0
  end

  # Calculate and display coverage percentage
  coverage_percent = (covered_lines.to_f / total_lines * 100).round(2)
  puts "Overall Coverage: #{coverage_percent}% (#{covered_lines}/#{total_lines} lines)"
  puts "Total uncovered lines: #{uncovered_lines.size}"

  # Print uncovered lines with their content
  if uncovered_lines.any?
    puts "\n=== Uncovered Lines ===\n"
    file_lines = File.readlines(found_file)
    uncovered_lines.each do |line_num|
      puts "#{line_num}: #{file_lines[line_num-1].strip}" if line_num <= file_lines.size
    end
  end

rescue => e
  puts "Error analyzing coverage data: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end
