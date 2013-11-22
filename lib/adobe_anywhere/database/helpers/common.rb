require 'adobe_anywhere/database'

module AdobeAnywhere

  class Database

    module Helpers

      class Common

        class << self

          attr_accessor :db

          def delete(*args); db.remove(*args) end # delete
          alias :remove :delete

          def find_by_id(id)
            #db.find_one('_id' => BSON::ObjectId(id))
            db.find_one('_id' => id)
          end # find_by_id

          def find(*args)
            db.find(*args)
          end # find

          def find_one(*args); db.find_one(*args) end

          def find_all
            self.find({ })
          end # find_all

          def insert(*args); db.insert(*args) end # insert
          alias :add :insert

          def update(id, data, options = { })
            data['modified_at'] = Time.now.to_i
            query = options[:query] || {'_id' => id }

            unless data.has_key?('_id')
              data = { '$set' => data }
            end

            db.update(query, data)
          end # update

          def save(*args); db.save(*args) end # save

        end # self

      end # Common

    end # Helpers

  end # Database

end # AdobeAnywhere