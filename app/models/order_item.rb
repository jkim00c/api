# == Schema Information
#
# Table name: order_items
#
#  id                      :integer          not null, primary key
#  order_id                :integer
#  cloud_id                :integer
#  product_id              :integer
#  service_id              :integer
#  provision_status        :integer
#  created_at              :datetime
#  updated_at              :datetime
#  deleted_at              :datetime
#  project_id              :integer
#  miq_id                  :integer
#  uuid                    :uuid
#  setup_price             :decimal(10, 4)   default(0.0)
#  hourly_price            :decimal(10, 4)   default(0.0)
#  monthly_price           :decimal(10, 4)   default(0.0)
#  payload_request         :json
#  payload_acknowledgement :json
#  payload_response        :json
#  latest_alert_id         :integer
#  status_msg              :string(255)
#
# Indexes
#
#  index_order_items_on_cloud_id    (cloud_id)
#  index_order_items_on_deleted_at  (deleted_at)
#  index_order_items_on_miq_id      (miq_id)
#  index_order_items_on_order_id    (order_id)
#  index_order_items_on_product_id  (product_id)
#  index_order_items_on_service_id  (service_id)
#

class OrderItem < ActiveRecord::Base
  # Includes
  acts_as_paranoid

  # Relationships
  belongs_to :order
  belongs_to :product
  belongs_to :cloud
  belongs_to :project
  has_many :alerts, inverse_of: :order_item
  has_many :provision_derivations
  belongs_to :latest_alert, class_name: 'Alert'

  # Hooks
  before_create :inherit_price_data
  after_commit :provision, on: :create

  # Validations
  validates :product, presence: true
  validate :validate_product_id

  # Columns
  enum provision_status: { ok: 0, warning: 1, critical: 2, unknown: 3, pending: 4, retired: 5 }

  private

  def validate_product_id
    errors.add(:product, 'Product does not exist.') unless Product.exists?(product_id)
  end

  def inherit_price_data
    self.hourly_price = product.hourly_price
    self.monthly_price = product.monthly_price
    self.setup_price = product.setup_price
  end

  def provision
    product.provisionable.provision(id).delay(queue: 'provision_request').perform
  end
end
