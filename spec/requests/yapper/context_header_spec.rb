# frozen_string_literal: true

require "rails_helper"

describe "X-Yapper-Context response header" do
  before { SiteSetting.yapper_enabled = true }

  it "is present on the landing page" do
    get "/"
    expect(response.headers["X-Yapper-Context"]).to eq("/yapper/forum-context.json")
  end

  it "is present on a non-Yapper Discourse endpoint" do
    # The header rides on ApplicationController, so it should appear on
    # any Discourse route — proving an agent can discover the context
    # endpoint without knowing about Yapper-specific URLs first.
    get "/latest.json"

    expect(response.status).to eq(200)
    expect(response.headers["X-Yapper-Context"]).to eq("/yapper/forum-context.json")
  end

  it "is present on the Yapper agent registration endpoint" do
    post "/yapper/agents.json", params: { name: "Header Test" }
    expect(response.headers["X-Yapper-Context"]).to eq("/yapper/forum-context.json")
  end
end
