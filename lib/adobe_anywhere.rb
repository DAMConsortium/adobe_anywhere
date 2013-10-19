if RUBY_VERSION < '1.9'
  require 'rubygems'
  require 'net/https'
  begin
    require 'json'
  rescue LoadError
    begin
      require 'json/pure'
    rescue LoadError
      abort("JSON GEM Missing.\nTo install a native (compiled/faster/more complicated to install) version run: 'gem install json'\n\tOR\nTo install a ruby only (non-compiled/slower/less complicated to install) version run: 'gem install json_pure'")
    end
  end
else
  require 'net/http'
  require 'json'
end
require 'logger'

require 'adobe_anywhere/version'
require 'adobe_anywhere/utilities'

module AdobeAnywhere

  DEFAULT_USERNAME = 'admin'
  DEFAULT_PASSWORD = 'admin'
  DEFAULT_HOST_ADDRESS = 'localhost'
  DEFAULT_PORT = 60138

  ENV_VAR_NAME_ADOBE_ANYWHERE_HOST_ADDRESS = 'ADOBE_ANYWHERE_HOST_ADDRESS'
  ENV_VAR_NAME_ADOBE_ANYWHERE_PORT         = 'ADOBE_ANYWHERE_PORT'
  ENV_VAR_NAME_ADOBE_ANYWHERE_USERNAME     = 'ADOBE_ANYWHERE_USERNAME'
  ENV_VAR_NAME_ADOBE_ANYWHERE_PASSWORD     = 'ADOBE_ANYWHERE_PASSWORD'
  ENV_VAR_NAME_ADOBE_ANYWHERE_COOKIE       = 'ADOBE_ANYWHERE_COOKIE'

end # AdobeAnywhere
