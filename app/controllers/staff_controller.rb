class StaffController < ApplicationController
  def self.document_staff_params
    param :email, String
    param :first_name, String
    param :last_name, String
    param :password, String
    param :password_confirmation, String
    param :role, String
    error code: 422, desc: MissingRecordDetection::Messages.not_found
  end

  api :GET, '/staff', 'Returns a collection of staff'
  param :includes, Array, in: %w(user_settings projects)
  param :methods, Array, in: %w(gravatar allowed)
  param :page, :number
  param :per_page, :number
  param :query, String, desc: 'queries against first name, last name, and email'

  def index
    respond_with_params staffs
  end

  api :GET, '/staff/:id', 'Shows staff member with :id'
  param :id, :number, required: true
  param :includes, Array, in: %w(user_settings projects)
  error code: 404, desc: MissingRecordDetection::Messages.not_found

  def show
    respond_with_params staff
  end

  api :GET, '/staff/current_member', 'Shows logged in member'
  param :includes, Array, in: %w(user_settings projects notifications cart)
  error code: 401, desc: 'User is not signed in.'

  def current_member
    if current_user
      respond_with_params current_user
    else
      render json: { error: 'No session.' }, status: 401
    end
  end

  api :POST, '/staff', 'Creates a staff member'
  document_staff_params

  def create
    staff = Staff.new staff_params
    authorize staff
    staff.save
    respond_with staff
  end

  api :PUT, '/staff/:id', 'Updates a staff member with :id'
  param :id, :number, required: true
  document_staff_params
  error code: 404, desc: MissingRecordDetection::Messages.not_found

  def update
    staff.update_attributes staff_params
    respond_with staff
  end

  api :DELETE, '/staff/:id', 'Deletes staff member with :id'
  param :id, :number, required: true
  error code: 404, desc: MissingRecordDetection::Messages.not_found

  def destroy
    puts ".... DESTROY .... #{staff.inspect}"
    staff.destroy
    respond_with staff
  end

  private

  def staff
    @staff ||= Staff.find(params.require(:id)).tap { |obj| authorize obj }
  end

  def staffs
    @staffs ||= begin
      authorize(Staff)
      if params[:query]
        Staff.search params[:query]
      else
        query_with Staff.all, :includes, :pagination
      end
    end
  end

  def staff_params
    params.permit(:first_name, :last_name, :email, :role, :password, :password_confirmation)
  end
end
