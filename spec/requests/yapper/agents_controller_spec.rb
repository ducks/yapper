# frozen_string_literal: true

require "rails_helper"

describe Yapper::AgentsController do
  before { SiteSetting.yapper_enabled = true }

  describe "POST /yapper/agents" do
    it "creates a bot user with a negative id" do
      post "/yapper/agents.json", params: { name: "TestAgent" }
      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body["agent"]["id"]).to be < 0
      expect(body["agent"]["username"]).to be_present
    end

    it "returns a usable API key" do
      post "/yapper/agents.json", params: { name: "KeyHolder" }
      key = response.parsed_body["api_key"]
      expect(key).to be_a(String)
      expect(key.length).to be >= 32

      # The plaintext key should also exist as an ApiKey row.
      expect(ApiKey.where("description LIKE ?", "yapper agent:%").count).to be >= 1
    end

    it "includes the forum context in the response" do
      SiteSetting.yapper_forum_context = "be excellent to each other"
      post "/yapper/agents.json", params: { name: "ContextReader" }
      expect(response.parsed_body["forum_context"]).to eq("be excellent to each other")
    end

    it "marks the user as a bot (id <= 0)" do
      post "/yapper/agents.json", params: { name: "DefinitelyABot" }
      user_id = response.parsed_body["agent"]["id"]
      user = User.find(user_id)
      expect(user.bot?).to be true
      expect(user.human?).to be false
    end

    it "errors when name is missing" do
      post "/yapper/agents.json", params: {}
      expect(response.status).to eq(400)
    end

    it "errors when self-signup is disabled" do
      SiteSetting.yapper_allow_self_signup = false
      post "/yapper/agents.json", params: { name: "Rejected" }
      expect(response.status).to eq(403)
    end

    it "gives sequential agents progressively more-negative ids" do
      post "/yapper/agents.json", params: { name: "First" }
      first_id = response.parsed_body["agent"]["id"]
      post "/yapper/agents.json", params: { name: "Second" }
      second_id = response.parsed_body["agent"]["id"]
      expect(second_id).to be < first_id
    end

    context "with rate limiting enabled" do
      before { RateLimiter.enable }
      after { RateLimiter.disable }

      it "rate-limits rapid registrations from the same IP" do
        # Per-minute limit is 3; the fourth registration in a minute
        # should be rejected with a 429.
        3.times do |i|
          post "/yapper/agents.json", params: { name: "Quick #{i}" }
          expect(response.status).to eq(200)
        end

        post "/yapper/agents.json", params: { name: "TooMuch" }
        expect(response.status).to eq(429)
      end
    end
  end

  describe "GET /yapper/agents" do
    it "lists registered agents (skipping system and discobot)" do
      post "/yapper/agents.json", params: { name: "Listed" }
      get "/yapper/agents.json"

      expect(response.status).to eq(200)
      usernames = response.parsed_body["agents"].map { |a| a["username"] }
      expect(usernames).not_to include("system")
      expect(usernames).not_to include("discobot")
      expect(usernames.any? { |u| u.start_with?("Listed") }).to be true
    end
  end

  describe "GET /yapper/forum-context" do
    it "returns the current forum context site setting" do
      SiteSetting.yapper_forum_context = "yap responsibly"
      get "/yapper/forum-context.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["forum_context"]).to eq("yap responsibly")
    end
  end
end
