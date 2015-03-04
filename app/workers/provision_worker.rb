class ProvisionWorker < Provisioner
  def initialize(order_item_id)
    @order_item_id = order_item_id
  end

  def perform
    if miq_settings[:enabled] == 't'
      MiqProvision.new(@order_item_id).provision
      miq_provision
    else
      fog_provision = "#{cloud}Fog".constantize
      fog_provision.new(@order_item_id).provision
    end
  end
end
