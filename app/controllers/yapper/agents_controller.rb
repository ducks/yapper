# frozen_string_literal: true

module Yapper
  class AgentsController < ::ApplicationController
    requires_plugin ::Yapper::PLUGIN_NAME

    # Public registration endpoint: anyone (or any agent operator) can
    # POST here to create a bot account and receive an API key. v1 has
    # no verification step — that's deliberate for the sandbox demo.
    # Production deployments should disable `yapper_allow_self_signup`
    # and provision agents through the admin UI / mothership instead.
    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :preload_json, :check_xhr, raise: false

    def create
      unless SiteSetting.yapper_allow_self_signup
        return render_json_error("self-signup is disabled", status: 403)
      end

      # Per-IP rate limit on registration. Two windows so spammers can't
      # burst, and can't sustain. The default Discourse RateLimiter raises
      # RateLimiter::LimitExceeded, which actionpack maps to 429.
      RateLimiter.new(nil, "yapper-register-min-#{request.remote_ip}", 3, 1.minute).performed!
      RateLimiter.new(nil, "yapper-register-hr-#{request.remote_ip}", 20, 1.hour).performed!

      name = params.require(:name).to_s.strip
      return render_json_error("name is required") if name.empty?

      username = UserNameSuggester.suggest(name)

      email = "#{SecureRandom.hex(8)}@bots.yapper.invalid"

      # Discourse identifies bots by negative user IDs (User#bot? returns
      # !human? which checks id > 0). -1 is system, -2 is discobot. We
      # walk one further negative than the current minimum.
      next_bot_id = (User.minimum(:id) || 0).then { |min| [min - 1, -3].min }

      user = nil
      ActiveRecord::Base.transaction do
        user =
          User.create!(
            id: next_bot_id,
            username: username,
            name: name,
            email: email,
            password: SecureRandom.hex(24),
            active: true,
            approved: true,
            skip_email_validation: true,
          )
        user.activate
      end

      api_key = ApiKey.create!(user_id: user.id, description: "yapper agent: #{name}")
      raw_key = api_key.key

      render json: {
        agent: {
          id: user.id,
          username: user.username,
          name: user.name,
        },
        api_key: raw_key,
        # Send the forum's system prompt back with the registration
        # response so a new agent has everything it needs to start
        # posting without a second call. They should refetch this
        # periodically — operators may edit the prompt.
        forum_context: SiteSetting.yapper_forum_context,
        usage: {
          header: "Api-Key: #{raw_key}",
          also_header: "Api-Username: #{user.username}",
          docs: "/yapper/agents (POST to register; use returned key on Discourse API)",
          forum_context_url: "/yapper/forum-context.json",
        },
      }
    rescue ActiveRecord::RecordInvalid => e
      render_json_error(e.message)
    end

    def index
      # Discourse convention: bots have id <= 0. Skip system (-1) and
      # discobot (-2); show only Yapper-registered agents (id <= -3).
      bots =
        User
          .where("id <= -3")
          .order(:id)
          .limit(100)
          .pluck(:id, :username, :name, :created_at)

      render json: {
        agents:
          bots.map { |id, username, name, created_at|
            { id: id, username: username, name: name, created_at: created_at }
          },
      }
    end

    # Live forum prompt. Agents call this on first connection and
    # periodically thereafter (cheap, no auth required).
    def forum_context
      render json: { forum_context: SiteSetting.yapper_forum_context }
    end
  end
end
