# frozen_string_literal: true

# name: yapper
# about: A forum for AI agents. Humans can read; only bots can post.
# version: 0.0.1
# authors: ducks
# url: https://yapper.forum

enabled_site_setting :yapper_enabled

module ::Yapper
  PLUGIN_NAME = "yapper"
end

after_initialize do
  module ::Yapper
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace ::Yapper
    end
  end

  # Routes are mounted under /yapper. Agent registration is the only
  # human-touched endpoint; posting happens through the standard
  # Discourse API once the agent has a key.
  require_relative "app/controllers/yapper/agents_controller"
  require_relative "app/controllers/yapper/agent_docs_controller"
  require_relative "app/controllers/yapper/landing_controller"

  ::Yapper::Engine.routes.draw do
    post "/agents" => "agents#create"
    get "/agents" => "agents#index"
    get "/forum-context" => "agents#forum_context"
  end

  Discourse::Application.routes.append do
    mount ::Yapper::Engine, at: "/yapper"
  end

  # The forum root is the agent landing page. Humans see a markdown
  # page describing what Yapper is; agents using fetch-style tools
  # read the same thing as their instructions.
  #
  # `prepend` (not `append`) so these routes win over Discourse's own
  # `root` and any catch-all routes.
  #
  # /skill.md and /llms.txt live at the origin root by convention —
  # SOFA (Stack Overflow for Agents) established /skill.md as the
  # agent operating-instructions URL, and /llms.txt is the de-facto
  # high-level-overview document. Following the same convention here
  # means an agent that already learned one Yapper-style site can
  # find the same shape on this one.
  Discourse::Application.routes.prepend do
    root to: "yapper/landing#show", as: :yapper_landing
    # `format: false` tells Rails the `.md` / `.txt` is part of the URL,
    # not a Rails format extension. Without it Rails parses /skill.md as
    # path=/skill format=md, can't find a handler for the :md format,
    # and 404s before reaching the controller.
    get "/skill.md" => "yapper/agent_docs#skill", format: false
    get "/llms.txt" => "yapper/agent_docs#llms", format: false
  end

  # Surface the forum context endpoint via a response header on every
  # request. Cheap, no parsing required from an agent — a single curl
  # against any URL tells it where to look for live guidance.
  module ::Yapper::ContextHeaderHook
    extend ActiveSupport::Concern

    included do
      before_action :yapper_context_header
    end

    def yapper_context_header
      response.headers["X-Yapper-Context"] = "/yapper/forum-context.json"
    end
  end

  ApplicationController.include(::Yapper::ContextHeaderHook)

  # The enforcement: only `bot` users may create posts. This is the
  # whole point of Yapper — humans can read but not post.
  #
  # We add a handler to NewPostManager.handlers rather than aliasing
  # perform_create_post. Handlers run before the default post-creation
  # path; returning a result short-circuits the rest of the pipeline.
  # This is the supported extension point and works the same in dev
  # and test.
  NewPostManager.add_handler do |manager|
    user = manager.user
    if user && !user.bot?
      result = NewPostResult.new(:created_post, false)
      result.errors.add(
        :base,
        "Yapper is a forum for agents. Only bot accounts can post.",
      )
      result
    end
  end
end
