#!/usr/bin/env ruby
# Isolated proposal validator; not a replacement for native CI execution.
require 'yaml'

TARGETS = {
  'installers' => './tests/installer-idempotency.tests.ps1',
  'loops-routing' => './tests/boundary-reference-authorization-parity.tests.ps1'
}.freeze
LANE_CONDITION = "matrix.lane == 'all' || matrix.lane == 'core'"

def violations(workflow)
  errors = []
  jobs = workflow.fetch('jobs')
  TARGETS.each do |job_name, command|
    job = jobs.fetch(job_name)
    steps = job.fetch('steps').select { |step| step['run'] == command }
    errors << "#{job_name}: exactly one direct suite invocation required" unless steps.length == 1
    errors << "#{job_name}: job must be unconditional and blocking" if job.key?('if') || job.key?('continue-on-error')
    errors << "#{job_name}: required-checks dependency missing" unless jobs.fetch('required-checks').fetch('needs').include?(job_name)
    steps.each do |step|
      errors << "#{job_name}: native pwsh required" unless step['shell'] == 'pwsh'
      errors << "#{job_name}: suite cannot be nonblocking" if step.key?('continue-on-error')
      expected_condition = job_name == 'installers' ? LANE_CONDITION : nil
      errors << "#{job_name}: unexpected step condition" unless step['if'] == expected_condition
    end
  end
  installers = jobs.fetch('installers')
  expected_lanes = [
    {'os' => 'windows-latest', 'lane' => 'core'},
    {'os' => 'windows-latest', 'lane' => 'mcp'},
    {'os' => 'windows-latest', 'lane' => 'clients'},
    {'os' => 'windows-latest', 'lane' => 'context'},
    {'os' => 'macos-latest', 'lane' => 'all'},
    {'os' => 'ubuntu-latest', 'lane' => 'all'}
  ]
  errors << 'installers: matrix changed' unless installers.dig('strategy', 'matrix', 'include') == expected_lanes
  errors << 'loops-routing: matrix changed' unless jobs.dig('loops-routing', 'strategy', 'matrix', 'os') == ['windows-latest', 'ubuntu-latest']
  TARGETS.each_key do |job_name|
    errors << "#{job_name}: runner changed" unless jobs[job_name]['runs-on'] == '${{ matrix.os }}'
  end
  errors
end

abort 'usage: ruby issue566-restoration.tests.rb WORKFLOW [BASE_WORKFLOW]' unless (1..2).cover?(ARGV.length)
candidate = YAML.load_file(ARGV[0])
errors = violations(candidate)
abort errors.join("\n") unless errors.empty?
puts 'PASS: both suites are blocking and scheduled on their intended native runner lanes'

if ARGV[1]
  baseline = YAML.load_file(ARGV[1])
  stripped = Marshal.load(Marshal.dump(candidate))
  TARGETS.each do |job_name, command|
    stripped['jobs'][job_name]['steps'].reject! { |step| step['run'] == command }
  end
  abort 'FAIL: proposal changes more than the two suite steps' unless stripped == baseline
  puts 'PASS: parsed workflow differs only by the two restored suite steps'
end

controls = 0
TARGETS.each do |job_name, command|
  %w[removed disabled wrong-shell nonblocking disabled-job missing-required-job duplicate].each do |mutation|
    changed = Marshal.load(Marshal.dump(candidate))
    job = changed['jobs'][job_name]
    step = job['steps'].find { |entry| entry['run'] == command }
    case mutation
    when 'removed' then job['steps'].delete(step)
    when 'disabled' then step['if'] = false
    when 'wrong-shell' then step['shell'] = 'bash'
    when 'nonblocking' then step['continue-on-error'] = true
    when 'disabled-job' then job['if'] = false
    when 'missing-required-job' then changed['jobs']['required-checks']['needs'].delete(job_name)
    when 'duplicate' then job['steps'] << step.dup
    end
    abort "FAIL: negative control accepted #{job_name}/#{mutation}" if violations(changed).empty?
    controls += 1
  end
end
puts "PASS: #{controls} independent negative controls rejected"
