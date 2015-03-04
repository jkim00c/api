require 'rails_helper'

describe AwsFog do
  it 'provisions infrastructure using fog' do
    order_item = prepare_fog_spec

    fog_provisioner = AwsFog.new(order_item.id)
    fog_provisioner.provision
    order_item.reload

    expect(order_item.provision_status).to eq 'ok'
    expect(order_item.payload_response).to be_present
  end

  def prepare_fog_spec
    enable_aws_fog_provisioning

    create(
      :order_item,
      product: create(
        :product,
        product_type: create(:product_type, name: 'infrastructure')
      )
    )
  end
end
