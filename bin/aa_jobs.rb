#!/usr/bin/env ruby
aa_base_dir = File.expand_path('../../', __FILE__)
aa_lib_dir = File.join(aa_base_dir, 'lib')

$:.unshift(aa_lib_dir) unless $:.include?(aa_lib_dir)

require 'pp'

require 'adobe_anywhere/api/utilities'
require 'cli'


#options[:host_address] = '172.24.15.220'
#options[:host_address] = '10.42.1.123'
#options[:host_address] = '10.42.1.109'
options[:log_level] = Logger::INFO
options[:log_to] = STDOUT

op = common_option_parser.new
op.on('--anywhere-host-address ADDRESS', 'The IP or hostname to use to contact the Adobe Anywhere Server when one is not specified in the XML.') { |v| options[:host_address] = v }
op.on('--anywhere-host-port PORT', 'The port to use to contact the Adobe Anywhere Server when one is not specified in the XML.') { |v| options[:host_port] = v }
op.on('--anywhere-username USERNAME', 'The username to login to the Adobe Anywhere Server when one is not specified in the XML.') { |v| options[:username] = v }
op.on('--anywhere-password PASSWORD', 'The password to login to the Adobe Anywhere Server when one is not specified in the XML.') { |v| options[:password] = v }
op.on('--help', 'Display this message.') { puts common_option_parser; exit }
add_common_options
op.parse_common

#puts options; exit
logger = Logger.new(options[:log_to])
logger.level = options[:log_level] if options[:log_level]
options[:logger] = logger

aa = AdobeAnywhere::API::Utilities.new(options)
#aa.http.log_request_body = true
#aa.http.log_response_body = true
#aa.http.log_pretty_print_body = true
aa.parse_response = true
aa.login

# @param [String] type (nil) Known types are SUCCESSFUL, WAITING, SCHEDULED, FAILED, RUNNING, CANCELED, CANCEL
jobs_summary = { }
total_jobs = 0
%w(SUCCESSFUL WAITING SCHEDULED FAILED RUNNING CANCELED CANCEL).each do |job_type|
  aa.job_list(job_type)
  parsed_response = aa.parsed_response
  stats = parsed_response['stats']
  total_results = stats['totalResults']
  total_jobs += total_results
  jobs_summary[job_type] = { total_results: total_results }
  #pp aa.parsed_response
end
jobs_summary['TOTAL'] = total_jobs
pp jobs_summary
exit
