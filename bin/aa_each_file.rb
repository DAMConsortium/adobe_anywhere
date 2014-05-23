#!/usr/bin/env ruby
#
# aa_each_file.rb --path-substitutions '{"/assets":"", "/":""}' --mount-point-name 'MEDIA' /assets
#
require 'rubygems'
require 'json'
require 'logger'
require 'optparse'
require 'shellwords'

@options = { }
def options; @options end

options[:executable_path] = '/Library/Scripts/ubiquity/adobe_anywhere/bin/aa'
options[:production_create_if_not_exists] = true
options[:asset_create_if_not_exists] = true
options[:recursive] = true
op = OptionParser.new
op.banner = "#{File.basename($0)} [options] file_path1 [file_path2] [file_path3] [...]"
op.on('--aa-executable-path PATH', 'The path to the Adobe Anywhere command line executable.', "\tdefault: #{options[:executable_path]}")
op.on('--mount-point-name NAME', 'The name of the media_paths mountpoint.', 'i.e: MEDIA') { |v| options[:mount_point_name] = v }
op.on('--path-substitutions JSON', 'Any path substitutions to perform on the file paths.', %q('{"/Volumes":"", "/root":""}')) { |v| options[:path_substitutions] = JSON.parse(v) }
op.on('--production-name NAME', 'A production name to add the assets to.') { |v| options[:production_name] = v }
op.on('--[no-]recursive', 'Determines if folders will be recursed into.', "\tdefault: #{options[:recursive] ? 'true' : 'false'}") { |v| options[:recursive] = v }
op.on('--[no-[production-create-if-not-exists', 'Determine if the production will be created if it does not exist.', "\tdefault: #{options[:production_create_if_not_exists] ? 'true' : 'false'}") { |v| options[:production_create_if_not_exists] = v }
op.on('--[no-]asset-create-if-not-exists', 'Will check to see if the asset exists before attempting to add it to the production.', "\tdefault: #{options[:asset_create_if_not_exists] ? 'true' : 'false'}") { |v| options[:asset_create_if_not_exists] = v }
op.on('--help', 'Displays this message') { puts op; exit }

original_arguments = ARGV.dup
remaining_arguments = original_arguments.dup

op.parse!(remaining_arguments)

paths = remaining_arguments
folder_paths = paths
#folder_paths << '/assets' if folder_paths.empty?
abort('A folder path must be specified.') if folder_paths.empty?

@executable_path = options[:executable_path]
@asset_create_if_not_exists = options[:asset_create_if_not_exists]
@path_substitutions = options[:path_substitutions] || { }
@mount_point_name = options[:mount_point_name]
@production_name = options[:production_name]
@production_create_if_not_exists = options[:production_create_if_not_exists]
@recursive = options[:recursive]

@logger = Logger.new(STDERR)
def logger; @logger end
logger.level = Logger::DEBUG

def asset_create_if_not_exists; @asset_create_if_not_exists end
def mount_point_name; @mount_point_name end
def path_substitutions; @path_substitutions end
def executable_path; @executable_path end
def production_name; @production_name end
def production_create_if_not_exists; @production_create_if_not_exists end
def file_path; @file_path end

def recursive; @recursive end

def execute(command_line)
  logger.debug { "Executing Command Line: #{command_line}" }
  response = `#{command_line}`
  logger.debug { "Response: #{(response.is_a?(Array) ? response.last : response)}"}
end

def aa_execute(*args)
  @executable_path ||= '/Library/Scripts/ubiquity/adobe_anywhere/bin/aa'

  _file_path = file_path.dup
  path_substitutions.each do |find, replace|
    _file_path.sub!(find, replace)
  end

  _file_path = File.join(mount_point_name, _file_path) if mount_point_name

  #command_line = %(#{executable_path} --method-name production_asset_add --method-arguments '{ "production_name": "#{production_name}", "media_paths": "eamedia://#{_file_path}", "create_asset_if_not_exists":true }')
  method_arguments_json = %({ "production_name": "#{production_name}", "media_paths": "eamedia://#{_file_path}", "create_asset_if_not_exists":#{asset_create_if_not_exists ? 'true' : 'false'}, "production_create_if_not_exists":#{production_create_if_not_exists ? 'true' : 'false'} })
  command_array = [ executable_path, '--method-name', 'production_asset_add', '--method-arguments', method_arguments_json ]
  command_line = command_array.shelljoin
  execute(command_line)
end

def get_production_name_for_file_path(file_path)
  # file_path_metadata = file_path.split('/')
  # "#{file_path_metadata[5]} - #{file_path_metadata[6]}"
  production_name
end

folder_path_count_total = folder_paths.length
folder_path_counter = 0
folder_paths.each do |folder_path|

  folder_path_counter += 1
  logger.info { "Processing Folder Path #{folder_path_counter} of #{folder_path_count_total}. '#{folder_path}'" }

  glob_pattern = if File.directory?(folder_path)
                   File.join(folder_path, (recursive ? '**/*' : '*'))
                 else
                   folder_path
                 end

  file_paths = Dir.glob(glob_pattern) # Recursive

  file_path_count_total = file_paths.length
  file_path_counter = 0

  file_paths.each do |_file_path|
    file_path_counter += 1
    unless File.file?(_file_path)
      logger.debug { "Skipping File Path #{file_path_counter} of #{file_path_count_total}. '#{file_path}'" }
      next
    end
    logger.debug { "Processing File Path #{file_path_counter} of #{file_path_count_total}. '#{file_path}'" }

    @file_path = _file_path
    @production_name = get_production_name_for_file_path(file_path)
    puts "Production Name: '#{production_name}' File Path: #{file_path}"
    aa_execute
  end

end


