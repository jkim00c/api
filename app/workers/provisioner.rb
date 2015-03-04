class Provisioner < Providers

  private

  def order_item
    @order_item ||= OrderItem.find @order_item_id
  end

  def product_provisioner
    Delayed::Worker.logger.debug "product type: #{order_item.product.product_type.name}"
    order_item.product.product_type.name
  end

  def service_type_id
    order_item.product.provisionable.service_type_id
  end

  def order_item_details
    details = {}
    answers = order_item.product.answers
    order_item.product.product_type.questions.each do |question|
      answer = answers.select { |row| row.product_type_question_id == question.id }.first
      details[question.manageiq_key] = answer.nil? ? question.default : answer.answer
    end
    details
  end

  def product_type
    order_item.product.product_type.name.capitalize.downcase
  end

  def cloud
    order_item.cloud.name.capitalize
  end

  def save_item(object)
    order_item.provision_status = :ok
    order_item.payload_response = object.to_json
  end

  def save_request(request)
    order_item.payload_request = request.to_json
  end

  def warning_retirement_error(message)
    order_item.provision_status = :warning
    order_item.status_msg = "Retirement failed: #{message}"[0..254]
  end

  def authentication_error
    order_item.provision_status = :critical
    order_item.status_msg = 'Bad request. Check for valid credentials and proper permissions.'
  end

  def critical_error(message)
    order_item.provision_status = :critical
    order_item.status_msg = message
  end

  def warning_error(message)
    order_item.provision_status = :warning
    order_item.status_msg = message
  end
end
