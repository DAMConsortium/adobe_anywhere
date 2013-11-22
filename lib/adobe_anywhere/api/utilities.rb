require 'adobe_anywhere'
require 'adobe_anywhere/api'

module AdobeAnywhere

  class API

    class Utilities < AdobeAnywhere::API

      def initialize(params = { })
        super(params)
        @parse_response = params.fetch(:parse_response, true)
      end

      # @param [String] name
      # @param [Hash] params
      # @option [Boolean] :case_sensitive (false)
      # @return [Array<String>]
      def export_preset_uri_by_name(name, params = { })
        case_sensitive = params[:case_sensitive]
        name = name.downcase unless case_sensitive

        logger.debug { "Looking up Export Preset URI by Name. #{name} Case Sensitive: #{case_sensitive ? 'true' : 'false'}" }

        export_presets_list

        export_preset_uris = [ ]
        export_presets = parsed_response['enclosures']

        export_presets.each do |export_preset|
          export_preset_name = export_preset['name']
          export_preset_name = export_preset_name.downcase unless case_sensitive

          if export_preset_name == name
            #logger.debug { "Match Found. #{name} == #{export_preset_name}" }
            export_preset_link = { }
            export_preset['links'].each { |link| export_preset_link = link and break if link['title'] == 'Enclosure data' }
            export_preset_uris << export_preset_link['href']
            #else
            #  logger.debug { "No Match Found. #{name} != #{export_preset_name}" }
          end
        end
        logger.debug { "Lookup Export Preset URI by Name Result: #{export_preset_uris.inspect}" }
        export_preset_uris
      end # export_preset_uri_by_name
      alias :export_preset_url_by_name :export_preset_uri_by_name

      # Creates a new group.
      #
      # @param [Hash] params
      # @option params [String] :authorizable_id REQUIRED The id of the group.
      # @option params [String] :given_name The name of the group.
      # @option params [String] :about_me A description of the group.
      def group_create(params = {})
        authorizable_id = search_hash!(params, :authorizable_id, :authorizableId, :authoriziableid, :id, :group_id)
        given_name = search_hash!(params, :given_name, :givenName, :givenname, :name, :group_name)
        about_me = search_hash!(params, :about_me, :description)

        data = { 'createGroup' => 1 }
        data['authorizableId'] = authorizable_id
        data['./profile/givenName'] = given_name
        data['./profile/aboutMe'] = about_me

        http_post_form('libs/granite/security/post/authorizables.html', data)
        return true if response.code == '201'
        false
      end # group_create

      # Deletes a group.
      # @param [String] authorizable_id
      def group_delete(authorizable_id)
        authorizable_id = authorizable_id.downcase
        http_post_form("home/groups/#{authorizable_id[0..0]}/#{authorizable_id}.rw.html", { 'deleteAuthorizable' => 1 })
        return true if response.code == '200'
        false
      end # group_delete

      # Adds a user to a group
      # @param [Hash] params
      # @option params [String] :groups_authorizable_id
      # @option params [String] :users_authorizable_id
      # @return [Boolean]
      def group_user_add(params = {})
        params = params.dup
        group_name = search_hash(params, :groups_authorizable_id, :group_id, :group_name)
        users_authorizable_id = search_hash(params, :users_authorizable_id, :user_id, :user_name)
        data = { }
        data['addMembers'] = users_authorizable_id

        group_name = group_name.downcase
        http_post_form("home/groups/#{group_name[0..0]}/#{group_name}.rw.userprops.html", data)
        return true if response.code == '200'
        false
      end # group_add_members
      alias :group_add_member :group_user_add
      alias :group_add_users :group_user_add
      alias :group_add_user :group_user_add


      # Creates a production conversion job
      #
      # Unlike {API#job_production_conversion_create} this method accepts a production name and will perform a lookup for
      # the production id
      #
      # @param [Hash] params
      # @option params [String] :production_name
      # @option params [Boolean] :case_sensitive
      # (see API#jobs_production_conversion_create)
      def job_production_conversion_create(params = {})
        params = params.dup
        case_sensitive = params[:case_sensitive]

        production_name = search_hash!(params, :production_name, :productionname)
        if production_name
          production_id = production_get_id_by_name(production_name, :case_sensitive => case_sensitive)
          params[:production_id] = production_id
        end

        super(params)
        return parsed_response['jcr:name'] if success?
        false
      end # job_production_conversion_create

      def production_access_add(params = { })
        params = params.dup
        production_name = search_hash!(params, :production_name, :productionname)
        production_id = search_hash!(params, :production_id, :productionId, :productionid)

        if production_name
          production_id = [*production_id]
          production_id += production_get_id_by_name(production_name)
          response = production_id.map { |pid| params[:production_id] = pid; super(params) }
          return response
        else
          params[:production_id] = production_id
          super(params)
        end
      end
      alias :production_grant_group_access :production_access_add
      alias :production_grant_user_access :production_access_add

      def production_access_delete(params = { })
        params = params.dup
        production_name = search_hash!(params, :production_name, :productionname)
        production_id = search_hash!(params, :production_id, :productionId, :productionid)

        if production_name
          production_id = [*production_id]
          production_id += production_get_id_by_name(production_name)
          response = production_id.map { |pid| params[:production_id] = pid; super(params) }
          return response
        else
          params[:production_id] = production_id
          super(params)
        end
      end
      alias :production_delete_group_access :production_access_delete
      alias :production_delete_user_access :production_access_delete

      def production_access_list(params = { })
        params = params.dup
        production_name = search_hash!(params, :production_name, :productionname)
        production_id = search_hash!(params, :production_id, :productionId, :productionid)

        if production_name
          production_id = [*production_id]
          production_id += production_get_id_by_name(production_name)
          response = production_id.map { |pid| params[:production_id] = pid; super(params) }
          return response
        else
          params[:production_id] = production_id
          super(params)
        end
      end

      # Adds an asset to a production.
      # @param [Hash] params
      # @option params [String] :production_name
      # @option params [String] :media_paths
      def production_asset_add(params = {})
        params = params.dup
        production_name = search_hash!(params, :production_name, :productionname)
        production_id = search_hash!(params, :production_id, :productionId, :productionid)

        if production_name
          production_id = [*production_id]
          production_id += production_get_id_by_name(production_name)
          response = production_id.map { |pid| params[:production_id] = pid; job_ingest_create(params) }
          return response
        else
          params[:production_id] = production_id
          job_ingest_create(params)
        end
      end # production_asset_add

      # Lists a productions assets.
      #
      # Unlike {API#production_asset_list} this method accepts a production name and will perform a lookup for
      # the production id.
      #
      # @param [Hash] params
      # @option params [String] :production_id
      # @option params [String] :production_name
      # @option params [Boolean] :case_sensitive
      def production_asset_list(params = {})
        params = params.dup
        case_sensitive = params[:case_sensitive]

        production_id = search_hash!(params, :production_id, :productionId, :productionid)
        production_id = [*production_id]

        production_name = search_hash!(params, :production_name, :productionname)

        # TODO Put in production version handling
        #production_version = find_hash_key!(params, :production_version, :version, :commit_id, :commit, :commitid) || 'HEAD'
        #production_version = 'HEAD'

        if production_name
          production_id += production_get_id_by_name(production_name, :case_sensitive => case_sensitive)
        end

        productions = { }
        production_id.each do |pid|
          super(pid)
          assets = parsed_response['assets']
          productions[pid] = assets
        end
        productions
      end # production_assets
      alias :productions_assets_list :production_asset_list

      # Creates a production.
      #
      # This method differs from {API#production_create} in that it returns just the production id of the
      # newly created production
      #
      # @param [Hash] params
      # @option params [String] name
      # @option params [String] description
      # @return [String] The Production ID
      def production_create(params = {})
        super(params)
        return false unless success?
        production_id = parsed_response['ea:productionId']
        production_id
      end # production_create
      alias :productions_create :production_create


      def production_delete(params = {})
        params = params.dup
        production_name = search_hash!(params, :production_name, :productionname)
        if production_name
          params[:production_id] = production_get_id_by_name(production_name).first
        end
        super(params)
      end # production_delete

      # @param [String] name
      # @param [Hash] params
      # @option params [Boolean] :case_sensitive
      # @return [Array] The array will be empty if nothing was found.
      def production_get_id_by_name(name, params = { })
        case_sensitive = params[:case_sensitive]
        name = name.dup.downcase unless case_sensitive

        logger.debug { "Looking up Production ID by Name. #{name} Case Sensitive: #{case_sensitive ? 'true' : 'false'}" }
        production_ids = [ ]
        productions_list
        productions = parsed_response['productions']
        return production_ids unless productions
        productions.each do |production|
          production_name = production['properties']['name']
          production_name = production_name.downcase unless case_sensitive
          production_ids << production['ea:productionId'] if production_name == name
        end
        logger.debug { "Lookup Production ID by Name Result: #{production_ids.inspect}" }
        production_ids
      end # production_get_id_by_name

      # Exports an asset from a production. Varies from productions_export_asset in that it allows you to specify the
      # production, exporter preset, and destination path parts by name.
      #
      # @param [Hash] params
      # @option params [String] :production_id
      # @option params [String] :exporter_preset
      # @option params [String] :destination_path
      # @option params [String] :asset_url
      # @option params [Boolean] :case_sensitive
      # @option params [String] :exporter_preset_name
      # @option params [String] :production_name
      # @option params [String] :asset_id
      # @option params [String] :mount_point_name
      # @option params [String] :mount_point_destination_path
      # @option params [String] :output_file_name
      # @return [String, false] The job URI if the job was created, false otherwise.
      def production_export_asset_with_name_lookup(params = {})
        logger.debug { "Parameters: #{params}"}
        params = params.dup

        case_sensitive = search_hash!(params, :case_sensitive)

        destination_path = search_hash(params, :destination_path, :destinationPath, :destinationpath)
        unless destination_path
          mount_point_name = search_hash!(params, :mount_point_name)
          mount_point_destination_path = search_hash!(params, :mount_point_destination_path)
          output_file_name = search_hash!(params, :output_file_name)

          if mount_point_name or mount_point_destination_path or output_file_name
            destination_path = mount_point_name ? mount_point_name : ''
            destination_path = File.join(destination_path, mount_point_destination_path ) if mount_point_destination_path
            destination_path = File.join(destination_path, output_file_name) if output_file_name
            destination_path = destination_path[1..-1] if destination_path.start_with?('/')
            destination_path = "eamedia://#{destination_path}" unless destination_path.start_with?('eamedia')
            params[:destination_path] = destination_path
          end
        end

        exporter_preset = search_hash(params, :exporter_preset, :exporterPreset, :exporterpreset)
        unless exporter_preset
          exporter_preset_name = search_hash!(params, :exporter_preset_name, :export_preset_name, :export_presets_name)
          logger.debug { "Exporter Preset Name: #{exporter_preset_name}"}
          exporter_preset_uri = export_preset_uri_by_name(exporter_preset_name, :case_sensitive => case_sensitive)
          exporter_preset_uri = exporter_preset_uri.first if exporter_preset_uri.is_a?(Array)
          params[:exporter_preset] = exporter_preset_uri
        end

        asset_url = search_hash(params, :asset_url, :assetURL, :asseturl)
        unless asset_url
          production_id = search_hash!(params, :production_id, :productionId, :productionid)
          unless production_id
            production_name = search_hash!(params, :production_name, :productionName, :productionname)
            production_id = production_get_id_by_name(production_name, :case_sensitive => case_sensitive)
          end
          production_id = production_id.first if production_id.is_a?(Array)

          params[:production_id] = production_id

          asset_id = search_hash(params, :asset_id, :assetId, :assetid)

          production_version = search_hash(params, :production_version, :productionVersion, :productionversion) || 'HEAD'
          asset_url = "#{http.to_s}/content/ea/git/productions/#{production_id}/#{production_version}/assets/#{asset_id}.v1.json"
          params[:asset_url] = asset_url
        end

        production_export_asset(params)
        return parsed_response['jcr:name'] if success?
        false
      end # production_export_asset_with_name_lookup
      alias :productions_export_asset_with_name_lookup :production_export_asset_with_name_lookup
      alias :export_asset :production_export_asset_with_name_lookup


      # Generates a hash of productions keyed by id.
      # @return [Hash]
      def production_list_by_id
        productions_hash = { }
        productions_list
        _response = parsed_response
        productions = _response['productions']
        productions.each do |production|
          production_id = production['ea:productionId']
          productions_hash[production_id] = production
        end
        productions_hash
      end # production_list_by_id
      alias :productions_list_by_id :production_list_by_id

      # Generates a hash of productions keyed by name. Productions who share a name will be grouped inside of an array
      # whereas productions with unique names will have a value that is a Hash.
      # @return [Hash]
      def production_list_by_name
        productions_hash = { }
        productions_list
        _response = parsed_response
        productions = _response['productions']
        productions.each do |production|
          production_name = production['properties']['name']
          _production = productions_hash[production_name]
          if _production
            unless _production.is_a?(Array)
              productions_hash[production_name] = [_production, production]
            else
              productions_hash[production_name] << production
            end
          else
            productions_hash[production_name] = production
          end
        end
        productions_hash
      end # production_list_by_name
      alias :productions_list_by_name :production_list_by_name

      # Creates a session associated with a production.
      # Unlike {API#production_session_create} the production can be specified by name using the :production_name
      # parameter
      #
      #
      # @param [Hash] params
      # @option params [String] :production_name
      # @see API#production_session_create
      def production_session_create(params = {})
        params = params.dup
        production_name = search_hash!(params, :production_name, :productionname)
        if production_name
          params[:production_id] = production_get_id_by_name(production_name).first
        end
        super(params)
        return parsed_response['ea:sessionId'] if success?
        false
      end # production_session_create
      alias :productions_sessions_create :production_session_create

      # Creates a user account and populates their profile.
      # @param [Hash] params
      # @option params [String] :authorizable_id
      # @option params [String] :password
      # @option params [String] :title
      # @option params [String] :given_name The users given name or first name
      # @option params [String] :family_name The users family name or last name
      # @option params [String] :job_title
      # @option params [String] :gender
      # @option params [String] :about_me
      # @option params [String] :email
      # @option params [String] :phone_number
      # @option params [String] :mobile
      # @option params [String] :street
      # @option params [String] :city
      # @option params [String] :state
      # @option params [String] :country
      # @option params [String] :postal_code
      def user_create(params = {})
        data = { 'createUser' => 1 }
        authorizable_id = search_hash!(params, :authorizable_id, :authorizableId, :authoriziableid, :id, :username)
        password = search_hash!(params, :password)

        data['authorizableId'] = authorizable_id
        data['rep:password'] = data['rep:re-password'] = password

        ### OPTIONAL PARAMETERS ##
        title = search_hash!(params, :title)
        given_name = search_hash!(params, :given_name, :givenName, :givenname, :first_name, :firstName, :firstname) || 'undefined'
        family_name = search_hash!(params, :family_name, :familyName, :familyname, :last_name, :lastName, :lastname) || 'undefined'
        job_title = search_hash!(params, :job_title, :jobTitle, :jobtitle)
        gender = search_hash!(params, :gender)
        about_me = search_hash!(params, :about_me, :aboutMe, :aboutme, :about)

        email = search_hash!(params, :email, :email_address) || 'undefined'
        phone_number = search_hash!(params, :phone_number, :phoneNumber, :phonenumber)
        mobile = search_hash!(params, :mobile, :mobile_phone_number)

        street = search_hash!(params, :street, :street_address, :streetAddress, :streetaddress)
        city = search_hash!(params, :city)
        state = search_hash!(params, :state)
        country = search_hash!(params, :country)
        postal_code = search_hash!(params, :postal_code, :postalCode, :postalcode, :zip_code, :zipCode, :zipcode)

        data['./profile/givenName']   = given_name #if given_name
        data['./profile/email']       = email #if email
        data['./profile/phoneNumber'] = phone_number #if phone_number
        data['./profile/street']      = street #if street
        data['./profile/city']        = city #if city
        data['./profile/country']     = country #if country
        data['./jcr:title']           = title #if title
        data['./profile/familyName']  = family_name #if family_name
        data['./profile/jobTitle']    = job_title #if job_title
        data['./profile/mobile']      = mobile #if mobile
        data['./profile/postalCode']  = postal_code #if postal_code
        data['./profile/state']       = state #if state
        data['./profile/gender']      = gender #if gender
        data['./profile/aboutMe']     = about_me #if about_me

        http_post_form('libs/granite/security/post/authorizables.html', data)
        return true if response.code == '201'
        false
      end # user_create
      alias :users_create :user_create

      # Edits a users profile and account properties
      # @param [Hash] params
      # @option params [String] :authorizable_id REQUIRED The unique id of the user. This is also the users username
      # @option params [String] :new_password
      # @option params [String] :current_password
      # @option params [String] :title
      # @option params [String] :given_name The users given name or first name
      # @option params [String] :family_name The users family name or last name
      # @option params [String] :job_title
      # @option params [String] :gender
      # @option params [String] :about_me
      # @option params [String] :email
      # @option params [String] :phone_number
      # @option params [String] :mobile
      # @option params [String] :street
      # @option params [String] :city
      # @option params [String] :state
      # @option params [String] :country
      # @option params [String] :postal_code
      def user_edit(params = {})
        data = { }

        authorizable_id   = search_hash!(params, :authorizable_id, :authorizableId, :authoriziableid, :username)
        new_password      = search_hash!(params, :new_password)
        current_password  = search_hash!(params, :current_password)

        title             = search_hash!(params, :title)
        given_name        = search_hash!(params, :given_name, :givenName, :givenname, :first_name, :firstName, :firstname)
        family_name       = search_hash!(params, :family_name, :familyName, :familyname, :last_name, :lastName, :lastname)
        job_title         = search_hash!(params, :job_title, :jobTitle, :jobtitle)
        gender            = search_hash!(params, :gender)
        about_me          = search_hash!(params, :about_me, :aboutMe, :aboutme, :about)

        email             = search_hash!(params, :email, :email_address)
        phone_number      = search_hash!(params, :phone_number, :phoneNumber, :phonenumber)
        mobile            = search_hash!(params, :mobile, :mobile_phone_number)

        street            = search_hash!(params, :street, :street_address, :streetAddress, :streetaddress)
        city              = search_hash!(params, :city)
        state             = search_hash!(params, :state)
        country           = search_hash!(params, :country)
        postal_code       = search_hash!(params, :postal_code, :postalCode, :postalcode, :zip_code, :zipCode, :zipcode)

        data['./profile/givenName'] = given_name if given_name
        data['./profile/email'] = email if email
        data['./profile/phoneNumber'] = phone_number if phone_number
        data['./profile/street'] = street if street
        data['./profile/city'] = city if city
        data['./profile/country'] = country if country
        data['./jcr:title'] = title if title
        data['./profile/familyName'] = family_name if family_name
        data['./profile/jobTitle'] = job_title if job_title
        data['./profile/mobile'] = mobile if mobile
        data['./profile/postalCode'] = postal_code if postal_code
        data['./profile/state'] = state if state
        data['./profile/gender'] = gender if gender
        data['./profile/aboutMe'] = about_me if about_me
        data['rep:password'] = data['rep:re-password'] = new_password
        data[':currentPassword'] = current_password

        authorizable_id = authorizable_id.downcase
        http_post_form("home/users/#{authorizable_id[0..0]}/#{authorizable_id}.rw.userprops.html", data)
        return true if response.code == '200'
        false
      end # user_edit
      alias :users_edit :user_edit

      # Deletes a user
      # @param [String] authorizable_id
      def user_delete(authorizable_id)
        authorizable_id = authorizable_id.downcase
        http_post_form("home/users/#{authorizable_id[0..0]}/#{authorizable_id}.rw.html", { 'deleteAuthorizable' => 1 })
        return true if response.code == '200'
        false
      end # user_delete
      alias :users_delete :user_delete

      #def users_photo_add(params = {})
      #  #
      #  #data = { }
      #  ##curl -u admin:admin -Fimage=@photos/johndoe.jpg -Fimage@TypeHint=nt:file http://localhost:60138/home/users/a/admin/profile/photos/primary
      #  #data['image'] = nil # Image File Contents
      #  #data['image@TypeHint'] = 'nt:file'
      #  #post('home/users/a/admin/profile/photos/primary', data)
      #  ##
      #  ##curl -u admin:admin -Fimage=@photos/johndoe.jpg -Fimage@TypeHint=nt:file http://localhost:60138/home/users/m/mwood/profile/photos/primary
      #  #username = params[:username]
      #  #path = "home/users/#{username[0..1]}/#{username}/profile/photos/primary"
      #end # users_photo_add

      # @param [Hash] job_details The output of a JobDetails call for a job
      # @param [Hash] options
      # @option options [Boolean] :raise_exceptions If true then exceptions will be raised if job_details in an unknown format
      # @return [False|String] The URI to the job details
      def get_self_link_href_from_job_details(job_details, options = { })
        raise_exceptions = options.fetch(:raise_exceptions, true)
        unless job_details.is_a?(Hash)
          return false unless raise_exceptions
          raise ArgumentError, "job_details argument is required to be a hash. job_details class name: #{job_details.class.name}. job_details: #{job_details}"
        end

        links = job_details['links']
        unless links.is_a?(Array)
          return false unless raise_exceptions
          raise ArgumentError, "job_details['links'] must be an array. links class name: #{links.class.name} job_details = #{job_details}"
        end

        self_link_index = links.index { |link| link['rel'].downcase == 'self' }
        unless self_link_index
          return false unless raise_exceptions
          raise ArgumentError, "job_details['links']['self'] not found. job_details = #{job_details}"
        end

        self_link = links[self_link_index]
        unless self_link.is_a?(Hash)
          return false unless raise_exceptions
          raise ArgumentError, "job_details['links']['self']['href'] not found. job_details = #{job_details}"
        end

        self_link['href']
      end # get_self_link_href_from_job_details


    end # Utilities

  end # API


end # AdobeAnywhere