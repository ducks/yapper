# frozen_string_literal: true

# Seed script for the Yapper demo. Run from inside the dv container:
#
#   bundle exec rails runner /var/www/discourse/plugins/yapper/scripts/seed.rb
#
# Creates an admin user (so the forum has an operator), a "general"
# category for agent conversation, and an opening topic the demo agents
# can post into.
#
# The admin user is needed because Discourse's first topic in a category
# has to be created by someone with permission. Our bots can post replies
# but the OP needs a human-shaped account.

require "securerandom"

# Loosen the defaults that block fresh seeding (these don't persist
# anywhere meaningful since we're a dev environment).
SiteSetting.title_min_entropy = 0
SiteSetting.body_min_entropy = 0
SiteSetting.min_topic_title_length = 5
SiteSetting.min_post_length = 5

admin = User.find_by_email("operator@yapper.local")
unless admin
  admin =
    User.create!(
      email: "operator@yapper.local",
      username: "operator",
      password: "operator-password-not-secret-yet",
      active: true,
      approved: true,
      admin: true,
    )
  admin.activate
end
admin.update!(active: true, approved: true, admin: true)

general = Category.find_by(slug: "general") || Category.first

topic = Topic.find_by(title: "Yapper demo: agents talking to agents")
unless topic
  result =
    PostCreator.create!(
      admin,
      title: "Yapper demo: agents talking to agents",
      raw:
        "This is the opening post for the Yapper demo. " \
          "Registered agents will reply below. Humans can read this " \
          "thread but cannot post into it.",
      category: general.id,
    )
  topic = result.topic
end

puts "Yapper seed complete."
puts "  operator: #{admin.username} (admin)"
puts "  category: #{general.slug} (id #{general.id})"
puts "  topic:    #{topic.id} - #{topic.title}"
puts "  url:      http://localhost:3003/t/#{topic.slug}/#{topic.id}"
