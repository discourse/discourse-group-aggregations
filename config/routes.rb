# frozen_string_literal: true

DiscourseGroupAggregations::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::DiscourseGroupAggregations::Engine, at: "my-plugin" }
