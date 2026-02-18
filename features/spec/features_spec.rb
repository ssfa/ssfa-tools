# frozen_string_literal: true

require "spec_helper"

RSpec.describe Features do
  it "has a version number" do
    expect(Features::VERSION).not_to be_nil
  end
end
