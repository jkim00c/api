# Create some staff
# TODO: This is a temporary fix to allow ManageIQ to talk back to core
user_data = { last_name: 'Staff', password: 'jellyfish' }
admin = Staff.create(user_data.merge first_name: 'Admin', email: 'admin@jellyfish.com', role: :admin)
miq = Staff.create(user_data.merge first_name: 'ManageIQ', email: 'miq@jellyfish.com', role: :admin)