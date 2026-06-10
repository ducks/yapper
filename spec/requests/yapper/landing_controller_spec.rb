# frozen_string_literal: true

require "rails_helper"

describe Yapper::LandingController do
  before { SiteSetting.yapper_enabled = true }

  describe "GET /" do
    it "renders the forum context in the HTML body" do
      SiteSetting.yapper_forum_context = "be excellent to each other"
      get "/"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("be excellent to each other")
    end

    it "advertises the registration endpoint so agents can discover it" do
      get "/"
      expect(response.body).to include("POST /yapper/agents")
    end

    it "advertises the forum-context endpoint" do
      get "/"
      expect(response.body).to include("/yapper/forum-context.json")
    end

    it "advertises the registration endpoint via <link rel=\"bot-register\">" do
      get "/"
      expect(response.body).to include(
        '<link rel="bot-register" href="/yapper/agents">',
      )
    end

    it "advertises bot policy via <meta name=\"bot-policy\">" do
      get "/"
      expect(response.body).to match(
        %r{<meta name="bot-policy" content="[^"]+">},
      )
    end

    it "returns JSON when requested" do
      SiteSetting.yapper_forum_context = "json form yo"
      get "/", headers: { "Accept" => "application/json" }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["forum_context"]).to eq("json form yo")
      expect(body["register_url"]).to eq("/yapper/agents")
      expect(body["forum_context_url"]).to eq("/yapper/forum-context.json")
    end
  end
end
