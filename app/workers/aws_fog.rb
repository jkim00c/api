class AwsFog
  def initialize(order_item_id)
    @order_item_id = order_item_id
  end

  def provision
    ENV['MOCK_MODE'] == 'true' ? Fog.mock! : Fog.unmock!
    product_provisioner = order_item.product.product_type.name.constantize
    begin
      product_provisioner.provision(order_item, aws_settings)
      order_item.provision_status = :ok
    rescue Excon::Errors::BadRequest
      order_item.provision_status = :critical
      order_item.status_msg = 'Bad request. Check authorization credentials.'
    rescue ArgumentError, StandardError, Fog::Compute::AWS::Error, NoMethodError => e
      order_item.provision_status = :critical
      order_item.status_msg = e.message
    ensure
      order_item.save
    end
  end

  def order_item
    @order_item ||= OrderItem.find @order_item_id
  end

  def aws_settings
    @aws_settings ||= Setting.find_by(hid: 'aws').settings_hash
  end

  class Provisioner
    attr_reader :order_item, :aws_settings

    def self.provision(order_item, aws_settings)
      new(order_item, aws_settings).provision
    end

    def initialize(order_item, aws_settings)
      @order_item = order_item
      @aws_settings = aws_settings
    end
  end

  class Infrastructure < Provisioner
    def provision
      # TODO: Must get an image_id from product types
      details = order_item.manageiq_answers.merge('image_id' => 'ami-acca47c4')
      server = connection.servers.create(details).tap { |s| s.wait_for { ready? } }

      order_item.instance_id = server.id
      order_item.private_ip = server.private_ip_address
      order_item.public_ip = server.public_ip_address
    end

    private

    def connection
      Fog::Compute.new(
        provider: 'AWS',
        aws_access_key_id: aws_settings[:access_key],
        aws_secret_access_key: aws_settings[:secret_key]
      )
    end
  end

  class Storage < Provisioner
    def provision
      instance_name = "id-#{order_item.uuid[0..9]}"
      storage = connection.directories.create(key: instance_name, public: true)

      order_item.instance_name = instance_name
      order_item.url = storage.public_url
    end

    private

    def connection
      Fog::Storage.new(
        provider: 'AWS',
        aws_access_key_id: aws_settings[:access_key],
        aws_secret_access_key: aws_settings[:secret_key]
      )
    end
  end

  class Databases < Provisioner
    def provision
      db_instance_id = "id-#{order_item.uuid[0..9]}"
      connection.create_db_instance(db_instance_id, details)

      order_item.instance_name = db_instance_id
      order_item.password = BCrypt::Password.create(@sec_pw)
      order_item.port = db.local_port
      order_item.public_ip = db.remote_ip
      order_item.url = db.local_address
      order_item.username = 'admin'
    end

    private

    def details
      order_item.manageiq_answers.merge(
        'MasterUserPassword' => SecureRandom.hex(5),
        'MasterUsername' => 'admin'
      )
    end

    def connection
      Fog::AWS::RDS.new(
        aws_access_key_id: aws_settings[:access_key],
        aws_secret_access_key: aws_settings[:secret_key]
      )
    end
  end
end
