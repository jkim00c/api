class ProvisionWorker
  def initialize(order_item_id)
    @order_item_id = order_item_id
  end

  def perform
    if miq_settings[:enabled]
      miq_provision
    else
      provider_provision
    end
  end

  private

  def order_item
    @order_item ||= OrderItem.find @order_item_id
  end

  def miq_settings
    @miq_settings ||= Setting.find_by(hid: 'manageiq').settings_hash
  end

  def miq_user
    @miq_user ||= Staff.find_by email: miq_settings[:email]
  end

  def miq_provision
    order_item.provision_status = :unknown
    order_item.payload_to_miq = message
    order_item.save

    handle_response message
  end

  def provider_provision
    # TODO: Provision according to cloud provider using fog.io
    cloud = order_item.cloud.name.capitalize
    provider = "#{cloud}Fog".constantize
    provider.new(@order_item_id).provision
  end

  def resource
    # TODO: verify_ssl needs to be changed, this is the only way I could get it to work in development.
    RestClient::Resource.new(
      miq_settings[:url],
      user: miq_settings[:username],
      password: miq_settings[:password],
      verify_ssl: OpenSSL::SSL::VERIFY_NONE,
      timeout: 120,
      open_timeout: 60
    )
  end

  def message
    @message ||= {
      action: 'order',
      resource: {
        href: "#{miq_settings[:url]}/api/service_templates/#{order_item.product.service_type_id}",
        referer: ENV['DEFAULT_URL'], # TODO: Move this into a manageiq setting
        email: miq_user.email,
        token: miq_settings[:token],
        order_item: {
          id: order_item.id,
          uuid: order_item.uuid.to_s,
          product_details: order_item_details
        }
      }
    }.to_json
  end

  def handle_response
    template = "api/service_catalogs/#{order_item.product.service_catalog_id}/service_templates"
    response = resource[template].post(message, content_type: 'application/json')

    begin
      data = ActiveSupport::JSON.decode(response)
      populate_order_item_with_respose_data(data)
    rescue => e
      order_item.provision_status = :unknown
      order_item.payload_reply_from_miq = {
        error: e.try(:response) || 'Request Timeout',
        message: e.try(:message) || "Action response was out of bounds, or something happened that wasn't expected"
      }.to_json
      raise
    ensure
      order_item.save
    end

    order_item.to_json
  end

  def status_from_response_code(code)
    case code
    when 200..299
      :pending
    when 400..407
      :critical
    else
      :warning
    end
  end

  def populate_order_item_with_respose_data(data)
    order_item.payload_reply_from_miq = data.to_json
    order_item.provision_status = status_from_response_code(response.code)
    order_item.miq_id = data['results'][0]['id'] if (200..299).cover?(response.code)
  end

  def aws_settings
    @aws_settings ||= Setting.find_by(hid: 'aws').settings_hash
  end

  def order_item_details
    details = order_item.manageiq_answers
    if aws_settings[:enabled]
      details['access_key_id'] = aws_settings[:access_key]
      details['secret_access_key'] = aws_settings[:secret_key]
      details['image_id'] = 'ami-acca47c4'
    end
    details
  end
end
