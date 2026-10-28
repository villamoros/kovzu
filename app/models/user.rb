class User < ApplicationRecord
  include KovzuRoles

  validates :clerk_id, presence: true, uniqueness: true

  def self.sync_from_clerk(clerk_user)
    primary_email = clerk_user.email_addresses&.find { it.id == clerk_user.primary_email_address_id }

    find_or_initialize_by(clerk_id: clerk_user.id).tap do |user|
      user.update!(
        email: primary_email&.email_address,
        first_name: clerk_user.first_name,
        last_name: clerk_user.last_name,
        image_url: clerk_user.image_url
      )
    end
  end

  def name
    [ first_name, last_name ].compact_blank.join(" ").presence || email
  end
end
