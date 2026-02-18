# frozen_string_literal: true

RSpec.describe Features::Cli do
  def run(*args)
    described_class.start(args)
  end

  describe "env" do
    it "환경변수를 출력한다" do
      expect { run("env") }.to output(/RUBY_VERSION/).to_stdout
    end
  end

  describe "init" do
    context "shell 인자 없이 호출하면" do
      it "사용법을 출력한다" do
        instance = described_class.new
        allow(instance).to receive(:exit)
        allow(described_class).to receive(:new).and_return(instance)
        expect { run("init") }.to output(/features init zsh/).to_stdout
      end
    end

    context "zsh 를 인자로 주면" do
      it "alias 스크립트를 출력한다" do
        expect { run("init", "zsh") }.to output(/alias f=/).to_stdout
      end
    end

    context "bash 를 인자로 주면" do
      it "alias 스크립트를 출력한다" do
        expect { run("init", "bash") }.to output(/alias f=/).to_stdout
      end
    end
  end

  describe "info" do
    let(:instance) { described_class.new }

    before do
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:cmd).and_return("  issue/1\n  main\n")
      allow(instance).to receive(:load_issues_from_branches)
      allow(instance).to receive(:issues).and_return({})
    end

    it "브랜치 목록을 조회한다" do
      expect { run("info") }.not_to raise_error
    end
  end

  describe "issue_list" do
    let(:instance) { described_class.new }

    before do
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:find_issues).and_return({})
    end

    it "이슈 목록을 조회한다" do
      expect { run("issue_list") }.not_to raise_error
    end
  end
end
