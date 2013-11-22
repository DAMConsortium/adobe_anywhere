require 'adobe_anywhere/database/helpers/common'

module AdobeAnywhere::Database::Helpers

  #class Database
  #
  #  module Helpers

      class Jobs < Common

        class << self

          def db=(_db)
            @db = _db.dup
            db.collection = 'jobs'
          end

          def save_changes(job, options = { })
            return_diff = options[:return_diff]
            job_record = options[:job_record]

            job_id = job['jcr:name']
            job_etag = job['jcr:etag']
            job_state = job['ea:jobState']
            job_last_modified = job['jcr:lastModified']
            job_last_progress = job['ea:progress']

            job_record ||= find_by_id(job_id)
            unless job_record
              new_record = true
              job_type = job['ea:jobType']
              timestamp = Time.now.to_i
              job_record = {
                  '_id' => job_id,
                  'type' => job_type,
                  'details_by_etag' => { job_etag => job },
                  'most_recent_etag' => job_etag,
                  'most_recent_state' => job_state,
                  'most_recent_lastModified' => job_last_modified,
                  'most_recent_progress' => job_last_progress,
                  'created_at' => timestamp,
                  'modified_at' => timestamp
              }
              record_id = db.insert(job_record)
              job_record['_id'] = record_id
              job_before = { }
              job_diff = job
            else
              new_record = false

              most_recent_etag = job_record['most_recent_etag']
              job_before = most_recent_etag ? job_record['details_by_etag'][most_recent_etag] : { }

              if job_etag != most_recent_etag
                job_record['details_by_etag'][job_etag] = job
                job_record['most_recent_etag'] = job_etag
                job_record['most_recent_state'] = job_state
                job_record['most_recent_lastModified'] = job_last_modified
                job_record['most_recent_progress'] = job_last_progress
                job_record['modified_at'] = Time.now.to_i
                db.save(job_record)

                # Diff job and job_
                job_diff = job.keep_if { |k, v| job_before[k] != v } if return_diff
              else
                job_diff = { }
              end

              #existing_job_detail = job_record['detail']
              #detail_match = (job_detail == existing_job_detail)
              #logger.debug { "Detail Match: #{detail_match}"}
              #unless detail_match
              #  logger.debug { 'Record has changed.' }
              #end
            end
            _response = { :record => job_record, :is_new => new_record, :before => job_before }
            _response[:difference] = job_diff if return_diff
            _response
          end # save_changes

          def add_callback_event(job, event_details)
            job_update = save_changes(job)
            job_record = job_update[:record]

            events = job_record['events'] ||= { }
            callbacks = events['callbacks'] ||= [ ]
            callbacks << event_details
            job_record['events']['callbacks'] = callbacks
            job_record['modified_at'] = Time.now.to_i
            db.save(job_record)
          end # add_callback_event

        end # self

      end # Jobs

  #  end # Helpers
  #
  #end # Database

end # AdobeAnywhere