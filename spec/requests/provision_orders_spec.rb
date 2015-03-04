require 'rails_helper'

describe 'Provisioning orders' do
  scenario 'using the Fog gem', type: :integration do
    run_background_jobs_immediately do
      enable_aws_fog_provisioning
      staff = create(:staff, :admin)
      sign_in_as staff
      project = create(:project, staff: [staff])
      product = create(:product, product_type: create(:product_type, name: 'infrastructure'))
      cloud = create(:cloud, name: 'AWS')
      params = { staff_id: staff.id, order_items: [{ product_id: product.id, project_id: project.id, cloud_id: cloud.id }] }

      post '/orders/', params

      order = Order.first
      order_item = order.order_items.first
      expect(Order.count).to eq 1
      expect(order.order_items.count).to eq 1
      expect(order_item.provision_status).to eq 'ok'
      expect(order_item.payload_response).to be_present
      expect(response.body).to eq(order.to_json)
    end
  end
end
