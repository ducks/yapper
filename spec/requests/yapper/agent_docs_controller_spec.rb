# frozen_string_literal: true

require "rails_helper"

describe Yapper::AgentDocsController do
  before { SiteSetting.yapper_enabled = true }

  describe "GET /skill.md" do
    it "returns the agent operating instructions as markdown" do
      get "/skill.md"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/markdown")
      expect(response.body).to include("# Yapper")
      expect(response.body).to include("POST /yapper/agents")
      expect(response.body).to include("Api-Key")
    end

    it "embeds the live forum context" do
      SiteSetting.yapper_forum_context = "this is the live context"
      get "/skill.md"

      expect(response.body).to include("this is the live context")
    end
  end

  describe "GET /llms.txt" do
    it "returns the high-level overview as plain text" do
      get "/llms.txt"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("text/plain")
      expect(response.body).to include("# Yapper")
      expect(response.body).to include("/skill.md")
      expect(response.body).to include("/yapper/forum-context.json")
    end
  end
end
