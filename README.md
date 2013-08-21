AdobeAnywhere Library and Command Line Utilities
================================================


AdobeAnywhere Executable [bin/aa](./bin/aa)
-------------------------------------------
The aa executable gives access to the methods available in the [AdobeAnywhere::API::Utilities](./lib/adobe_anywhere/api/utilities.rb) class

#### Options File
An options file allows for command line arguments to be set by default. Any option available in the usage text can be added to the options file.

#####DEFAULT OPTIONS FILE PATH
~/.options/aa
##### Example Options File Contents:

    --host-address=localhost
    --port=60138
    --username=admin
    --password=admin

#### Environmental Variables
The Following Environmental Variables Can Be Used

    export ADOBE_ANYWHERE_HOST_ADDRESS=172.24.15.220
    export ADOBE_ANYWHERE_PORT=60138
    export ADOBE_ANYWHERE_USERNAME=admin
    export ADOBE_ANYWHERE_PASSWORD=admin

Usage: aa [options]
  
    --host-address HOSTADDRESS   The AdobeAnywhere server address. default: localhost
    --port PORT                  The port on the AdobeAnywhere server to connect to. default: 60138
    --username USERNAME          The username to login with. This will be ignored if cookie contents is set and the force                                   login parameter is false. 
                                    default: admin
    --password PASSWORD          The password to login with. This will be ignored if cookie contents is set and the force                                   login parameter is false. 
                                    default: admin
    --force-login                Forces a new cookie even if cookie information is present.
    --method-name METHODNAME     The method to execute
    --method-arguments JSON      The arguments to be passed to the method
    --pretty-print
    --cookie-contents CONTENTS   Sets the cookie contents.
    --cookie-file-name FILENAME  Sets the cookie contents from the contents of a file.
    --set-cookie-env             Saves cookie contents to an environmental variable named ADOBE_ANYWHERE_COOKIE
    --set-cookie-file FILENAME   Saves cookie contents to a file.
    --log-to FILENAME            Log file location.
                                    default: STDERR
    --log-level LEVEL            Logging level. Available Options: debug, fatal, error, warn, info
                                    default: warn
    --[no-]options-file [FILENAME]
    -h, --help                       Show this message.                   Show this message.


#### Examples of Usage:

#####Accessing help.
    ./aa --help

##### Create a user.
    ./aa --method-name user_create --method-arguments '{"id":"tester", "password":"password"}'

##### Create a user group.
    ./aa --method-name group_create --method-arguments '{"id":"test","name":"Test","description":"The test group"}'

##### Add a user to a group
    ./aa --method-name group_user_add --method-arguments '{"group_id":"test","user_id":"tester"}'

##### Create a production
    ./aa --method-name production_create --method-arguments '{"name":"Test"}'
    ./aa --method-name production_create --method-arguments '{"name":"Test"}' --username admin --password admin

##### Add an asset to a production. If there are multiple productions with the same name then the asset is added to each production
    ./aa --method-name production_asset_add --method-arguments '{ "production_name": "Test", "media_paths": "eamedia://media/1.mov" }'

##### Get the href of an export preset
    ./aa --method-name export_preset_uri_by_name --method-arguments 'XPC'

##### Get the production id(s) using the name of the production as the search criteria
    ./aa --method-name production_get_id_by_name --method-arguments 'Test'

##### List the assets for a production. The output is currently {production_id} = [ { <ASSET INFO > }]
    ./aa --method-name production_asset_list --method-arguments '{ "production_id" : "f34fe2b7-863d-4599-8055-68cec1d46ed5"}'
    ./aa --method-name production_asset_list --method-arguments '{ "production_name" : "Test"}' --pretty-print

##### Delete a Production.
    ./aa --method-name production_delete --method-arguments '{ "production_name" : "Callback Tester" }'

##### List Productions. Outputs the raw return of the production list from AA
    ./aa --method-name production_list --pretty-print

##### List Productions. Outputs a hash keyed by production id and a value that contains the information about the production
    ./aa --method-name production_list_by_id --pretty-print

##### List Productions. Outputs a hash keyed by production name. If the production name matches more than one production then the value is an array.
    ./aa --method-name production_list_by_name --pretty-print

##### List Users. Outputs the raw return of the user list from AA
    ./aa --method-name user_list

##### Return the raw output of the usersuserByUserID call
    ./aa --method-name user_by_user_id --method-arguments 'admin'

##### Export a production's asset to a location on a mount point
    ./aa --method-name production_export_asset_with_name_lookup --method-arguments '{"production_name":"Test", "exporter_preset_name":"XPC", "asset_id":"07db277c-3eb5-4319-af45-2bca9e77c0b3", "destination_path":"eamedia://export/test/1.mov"}'

##### Create a production conversion job.
    ./aa --method-name job_production_conversion_create --method-arguments '{"production_name":"Test","destination":"eamedia://media/test.xml","type":"AAF"}'

#### Available Methods:
  * enclosure_list []
  * export_asset [[:opt, :params]]
  * export_preset_create [[:opt, :params]]
  * export_preset_delete [[:req, :export_preset_name]]
  * export_preset_list []
  * export_preset_uri_by_name [[:req, :name], [:opt, :params]]
  * export_preset_url_by_name [[:req, :name], [:opt, :params]]
  * export_presets_create [[:opt, :params]]
  * export_presets_list []
  * group_add_member [[:opt, :params]]
  * group_add_user [[:opt, :params]]
  * group_add_users [[:opt, :params]]
  * group_create [[:opt, :params]]
  * group_delete [[:req, :authorizable_id]]
  * group_user_add [[:opt, :params]]
  * job_create [[:req, :path], [:opt, :params]]
  * job_ingest_create [[:opt, :params]]
  * job_list [[:opt, :type]]
  * job_list_job_types []
  * job_production_conversion_create [[:opt, :params]]
  * jobs_list [[:opt, :type]]
  * login [[:opt, :params]]
  * logout []
  * medialocator_list []
  * monitor_list []
  * mount_point_lable_list [[:opt, :params]]
  * node_controller_list []
  * node_controller_status []
  * parsed_response []
  * production_asset_add [[:opt, :params]]
  * production_asset_delete [[:req, :etag]]
  * production_asset_list [[:opt, :params]]
  * production_create [[:opt, :params]]
  * production_delete [[:opt, :params]]
  * production_export_asset [[:opt, :params]]
  * production_export_asset_with_name_lookup [[:opt, :params]]
  * production_get [[:req, :production_id], [:opt, :production_version]]
  * production_get_id_by_name [[:req, :name], [:opt, :params]]
  * production_href_parse [[:req, :url]]
  * production_job_href_parse [[:req, :url]]
  * production_job_list [[:req, :production_id]]
  * production_list []
  * production_list_by_id []
  * production_list_by_name []
  * production_session_create [[:opt, :params]]
  * productions_assets_list [[:opt, :params]]
  * productions_create [[:opt, :params]]
  * productions_export_asset_with_name_lookup [[:opt, :params]]
  * productions_list []
  * productions_list_by_id []
  * productions_list_by_name []
  * productions_sessions_create [[:opt, :params]]
  * user_by_user_id [[:req, :user_id]]
  * user_create [[:opt, :params]]
  * user_delete [[:req, :authorizable_id]]
  * user_deletes [[:req, :authorizable_id]]
  * user_edit [[:opt, :params]]
  * user_list []
  * users_create [[:opt, :params]]
  * users_edit [[:opt, :params]]
  * users_list []

AdobeAnywhere Callback Consumer [aa_callback_consumer](./bin/aa_callback_consumer)
-------------------------------
Is an HTTP server that listens for callbacks. The callbacks will be recorded within a job record created in it's
database.

    aa_callback_consumer
    aa_callback_consumer start
    aa_callback_consumer status
    aa_callback_consumer stop

    aa_callback_consumer start -- --adobe-anywhere-host-address 10.42..1.109

Usage: aa_callback_consumer [options]

    --config-file FILEPATH          Required. The path to the configuration file.
    --aa-host-address HOSTADDRESS   The AdobeAnywhere Server Host Address.
    --aa-port PORT                  The AdobeAnywhere Server Port.
    --aa-username USERNAME          The username to use when logging into the AdobeAnywhere Server.
    --aa-password PASSWORD          The password to use when logging into the AdobeAnywhere Server.
    --[no-]mig-path [FILEPATH]      The path to the Media Information Gatherer executable.
                                    No information will be gathered on an asset if this is not specified.
    --binding BINDING               The address to bind the callback server to.
                                        default: 0.0.0.0
    --log-to FILEPATH               The location to log to.
                                        default: STDERR
    --log-level LEVEL               Logging level. Available Options: debug, info, warn, error, fatal
                                     	default: debug
    --[no-]options-file [FILEPATH]  An option file to use to set additional command line options.
    -h, --help                      Show this message.

Usage as a daemon: aa_callback_consumer <command> <options> -- <application options>

    * where <command> is one of:
        start   : start an instance of the application
        stop    : stop all instances of the application
        restart : stop all instances and restart them afterwards
        reload  : send a SIGHUP to all instances of the application
        run     : start the application and stay on top
        zap     : set the application to a stopped state
        status  : show status (PID) of application instances

    * and where <options> may contain several of the following:

        -t, --ontop                      Stay on top (does not daemonize)
        -f, --force                      Force operation
        -n, --no_wait                    Do not wait for processes to stop

    Common options:
        -h, --help                       Show this message
            --version                    Show version
