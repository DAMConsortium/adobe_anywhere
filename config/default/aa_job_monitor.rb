# Possible Job States
# CANCEL
# CANCELED
# FAILED
# RUNNING
# SCHEDULED
# SUCCESSFUL
# WAITING
#
# Available Job Types
# com.adobe.ea.jobs.export
# com.adobe.ea.jobs.ingest
# com.adobe.ea.jobs.productionconversion
# com.adobe.ea.jobs.transfer
#
#{
#  "ea:requestId":"d820d351-d4ef-4ed6-8f03-fbee9a8f32e0",
#  "ea:publishAsMessage":false,
#  "ea:jobState":"WAITING",
#  "jcr:etag":"\"6aa85b0b-6bef-4a01-8f34-b6c7b4b2cac4\"",
#  "jcr:created":"2013-08-09T13:54:55.368-06:00",
#  "ea:retryCount":0,
#  "ea:progress":0,
#  "ea:jobType":"com.adobe.ea.jobs.transfer",
#  "jcr:name":"32ce264c-c8f8-4206-b62f-58cb89a42b9a",
#  "jcr:createdBy":"unknown",
#  "ea:beforeSaveJobTypeCallbackURI":"http://10.42.1.122:4567",
#  "ea:metadata":{},
#  "ea:parameters":{
#    "files":[
#      {
#        "baseFile":true,
#        "dest":"eamedia://export/EAMedia%20File%20Transfer%5C9c32677b-67a4-4d1c-bd75-dcf5277895d1%5Ctest.mov",
#        "src":"/assets/FCPXML/test.mov",
#        "transfer":true
#      }
#    ]
#  },
#  "ea:result":{}
#}

@default_successful_job_task = {
    :executable => { :value => %q("echo \'#{JSON.generate({ 'job' => job, 'production' => production, 'assets' => assets, 'asset_media_information' => asset_media_information})}\'   >> /tmp/callback_task_execute"), :eval => true },
}
@default_failed_job_task = {
    :executable => { :value => %q("echo #{job['jcr:jobName']} FAILED >> /tmp/aa_jobs"), :eval => true },
}
@default_job_tasks = {
    'SUCCESSFUL' => @default_successful_job_task,
    'FAILED' => @default_failed_job_task,
}

@tasks = {
    'com.adobe.ea.jobs.export' => @default_job_tasks,
    'com.adobe.ea.jobs.ingest' => @default_job_tasks,
    'com.adobe.ea.jobs.productionconversion' => @default_job_tasks,
    'com.adobe.ea.jobs.transfer' => @default_job_tasks,
}

@path_substitutions = { 'eamedia://Export' => '/Volumes/video/export' }