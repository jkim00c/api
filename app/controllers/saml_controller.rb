class SamlController < ApplicationController
  before_action :saml_enabled?

  require 'uri'

  def init
    respond_to do |format|
      format.html { redirect_to idp_login_request_url request }
      format.json { render json: { url: saml_init_url } }
    end
  end

  def consume
    response = idp_response params
    response.settings = saml_settings request
    if response.is_valid?
#      puts "response.inspect .... #{response.inspect}"
#      user = Staff.find_by email: response_email(response)
      puts "response e-mail .... #{response.attributes['email']}"
      user = Staff.find_by email: response.attributes['email']
      puts "user .... #{user.inspect}"
      return saml_failure if user.nil?
      sign_in user
      redirect_to authenticated_url
    else
      saml_failure
    end
  end
  
  def metadata
    meta = OneLogin::RubySaml::Metadata.new
    render :xml => meta.generate(saml_settings(request))
    #render :xml => meta.generate(saml_settings(request)), :content_type => "application/samlmetadata+xml"
  end

  private

  def saml_enabled?
    @settings = Setting.find_by(hid: 'saml').settings_hash
    return saml_failure unless @settings[:enabled]
    true
  end

  def saml_failure
    head 404, content_type: :plain
    false
  end

  def response_email(response)
    [
      response.name_id,
      response.attributes['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'],
      response.attributes['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn']
    ].find { |v| v[/^(([A-Za-z0-9]+_+)|([A-Za-z0-9]+\-+)|([A-Za-z0-9]+\.+)|([A-Za-z0-9]+\++))*[A-Z‌​a-z0-9]+@((\w+\-+)|(\w+\.))*\w{1,63}\.[a-zA-Z]{2,6}$/i] }
  end

  def idp_response(params)
    OneLogin::RubySaml::Response.new(params[:SAMLResponse])
  end

  def saml_settings(request)
#    settings = OneLogin::RubySaml::Settings.new

#    settings.assertion_consumer_service_url = saml_consume_url host: request.host
    #settings.assertion_consumer_service_url = saml_consume_url host: request.host
#    settings.issuer = "http://#{request.port == 80 ? request.host : request.host_with_port}/saml/metadata.xml"
#    settings.idp_sso_target_url = 'http://openam.micropaas.io:8080/openam/SSORedirect/metaAlias/PaaS%20Portal%20UI/idp'
#    settings.idp_sso_target_url = 'http://openam.micropaas.io:8080/openam/SSORedirect/metaAlias/PaaS+Portal+UI/idp'
#    settings.idp_sso_target_url = 'http://openam.micropaas.io:8080/openam'
#    settings.idp_sso_target_url = URI.escape('http://openam.micropaas.io:8080/openam/SSORedirect/metaAlias/PaaS Portal UI/idp')
    #settings.idp_sso_target_url = 'http://openam.micropaas.io:8080/openam?realm=PaaS+Portal+UI'
#    settings.idp_sso_target_url = 'http://openam.micropaas.io:8080/openam/saml2/jsp/spSSOInit.jsp?metaAlias=/PaaS+Portal+UI/idp'
#    settings.idp_entity_id = 'http://openam.micropaas.io:8080/openam'
#    settings.idp_sso_target_url = @settings[:target_url]
#    settings.idp_cert = @settings[:certificate]
#    settings.idp_cert_fingerprint = @settings[:fingerprint]
#    settings.authn_context = 'urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport'
   
    #settings.idp_sso_target_url = URI.escape('http://openam.micropaas.io:8080/openam/SSORedirect/metaAlias/PaaS Portal UI/idp')
    #settings.authn_context = 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'

    # using metadata from the openam server
    idp_metadata_parser = OneLogin::RubySaml::IdpMetadataParser.new

    settings = idp_metadata_parser.parse_remote('http://openam.micropaas.io:8080/openam/saml2/jsp/exportmetadata.jsp?realm=Jellyfish')
    #puts "settings ............. #{settings.inspect}"
    settings.assertion_consumer_service_url = saml_consume_url host: request.host
    #settings.issuer = "http://#{request.port == 80 ? request.host : request.host_with_port}"
    settings.issuer = 'http://jellyfish.micropaas.io:3000/saml/metadata.xml'
    #settings.idp_entity_id = 'http://openam.micropaas.io:8080/openam'
    #settings.name_identifier_format = 'urn:oasis:names:tc:SAML:2.0:nameid-format:email'
    #settings.authn_context = 'urn:oasis:names:tc:SAML:2.0:metadata'
    settings.authn_context = 'urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport'

    settings
  end

  def idp_login_request_url(request)
    idp_request = OneLogin::RubySaml::Authrequest.new
    idp_request.create saml_settings request
  end

  # User Redirection urls

  def authenticated_url
    'http://jellyfish.micropaas.io:5000/dashboard'
#    @settings[:redirect_url]
  end
end
