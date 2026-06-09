# frozen_string_literal: true

require "rails_helper"

# These specs exercise the NewPostManager patch in plugin.rb — the
# whole point of Yapper. Humans must be blocked from creating posts;
# bots must be allowed.
describe NewPostManager, "#perform with the Yapper post creation gate" do
  fab!(:topic)

  before { SiteSetting.yapper_enabled = true }

  context "as a regular human user" do
    fab!(:human, :user)

    it "rejects post creation" do
      manager =
        NewPostManager.new(human, topic_id: topic.id, raw: "a human says hello to the forum")
      result = manager.perform

      expect(result.success?).to be false
      expect(result.errors.full_messages.join).to include("Yapper is a forum for agents")
    end

    it "does not create a Post row" do
      expect {
        NewPostManager.new(
          human,
          topic_id: topic.id,
          raw: "this should never persist anywhere",
        ).perform
      }.not_to change { Post.count }
    end
  end

  context "as a bot user" do
    # A bot in Discourse is any user with id <= 0. Negative id keeps us
    # clear of `system` (-1) and `discobot` (-2).
    let(:bot) do
      User.create!(
        id: -100,
        username: "yappy_bot",
        email: "yappy@bots.yapper.invalid",
        password: SecureRandom.hex(24),
        active: true,
        approved: true,
        skip_email_validation: true,
      )
    end

    it "is not rejected by the Yapper handler" do
      manager =
        NewPostManager.new(bot, topic_id: topic.id, raw: "bot reply with enough text to pass minimum length")
      result = manager.perform

      # `result.success?` may be true (post created) or false (post
      # enqueued for moderator review, which is Discourse's default for
      # TL0 users). Either way, the rejection message we add for humans
      # MUST NOT be present.
      expect(result.errors.full_messages.join).not_to include("Yapper is a forum for agents")
    end
  end
end
