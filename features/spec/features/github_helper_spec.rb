# frozen_string_literal: true

require "features/cli"

RSpec.describe Features::GithubHelper do
  subject(:helper) { Class.new { include Features::GithubHelper }.new }

  let(:open_issue) do
    { number: 1, title: "테스트 이슈", labels: [], assignees: [], state: "OPEN" }
  end

  let(:closed_issue) do
    { number: 2, title: "완료된 이슈", labels: [], assignees: [], state: "CLOSED" }
  end

  let(:issue_with_metadata) do
    {
      number: 3,
      title: "메타 이슈",
      labels: [{ "name" => "bug", "color" => "ff0000" }],
      assignees: [{ "login" => "simon" }],
      state: "OPEN"
    }
  end

  let(:gh_response) do
    [{ "number" => 1, "title" => "테스트 이슈", "labels" => [], "assignees" => [], "state" => "OPEN" }].to_json
  end

  describe "#cmd" do
    it "명령어를 실행하고 stdout 을 반환한다" do
      allow(Open3).to receive(:capture3).with("echo hello").and_return(["hello\n", "", nil])
      expect(helper.cmd("echo hello")).to eq("hello\n")
    end

    it "last_cmd 에 마지막 실행 명령어를 저장한다" do
      allow(Open3).to receive(:capture3).with("echo hello").and_return(["hello\n", "", nil])
      helper.cmd("echo hello")
      expect(helper.last_cmd).to eq("echo hello")
    end
  end

  describe "#issue_num_from_branch" do
    where(:branch, :expected) do
      [
        ["issue/42", "42"],
        ["issues/7", "7"],
        ["feature/3", "3"],
        ["main", nil],
        ["issue/10-fix-bug", "10"]
      ]
    end

    with_them do
      it "브랜치명에서 이슈 번호를 추출한다" do
        expect(helper.issue_num_from_branch(branch)).to eq(expected)
      end
    end
  end

  describe "#find_issues" do
    before do
      allow(helper).to receive(:cmd).and_return(gh_response)
    end

    it "gh 를 호출해서 이슈를 해시로 반환한다" do
      result = helper.find_issues(["1"], state: "open")
      expect(result).to include("1" => hash_including(title: "테스트 이슈"))
    end

    it "issue_numbers 가 비어있으면 limit 으로 전체 조회한다" do
      result = helper.find_issues(state: "open")
      expect(result).to include("1")
    end
  end

  describe "#load_issues_from_branches" do
    before do
      allow(helper).to receive(:find_issues).and_return({ "1" => open_issue })
      helper.instance_variable_set(:@issues, nil)
    end

    attr_accessor :issues

    it "브랜치 목록에서 이슈를 로드한다" do
      helper.extend(Module.new { attr_accessor :issues })
      helper.load_issues_from_branches(["issue/1"])
      expect(helper.issues).to include("1" => open_issue)
    end
  end

  describe "#make_title" do
    where(:state, :assignees, :labels, :includes, :excludes) do
      [
        [true, true, true, ["메타 이슈", "bug", "@simon", "open"], []],
        [false, true, true, ["bug", "@simon"], ["open"]],
        [true, true, false, ["@simon", "open"], ["bug"]],
        [true, false, true, ["bug", "open"], ["@simon"]]
      ]
    end

    with_them do
      it "옵션별로 제목 구성 요소를 포함/제외한다" do
        result = helper.make_title(issue_with_metadata, state:, assignees:, labels:)

        includes.each { |text| expect(result).to include(text) }
        excludes.each { |text| expect(result).not_to include(text) }
      end
    end

    it "issue 가 nil 이면 nil 을 반환한다" do
      expect(helper.make_title(nil)).to be_nil
    end
  end

  describe "#paint_assignees" do
    it "담당자 목록을 포맷해서 반환한다" do
      result = helper.paint_assignees([{ "login" => "simon" }])
      expect(result).to include("@simon")
    end

    it "담당자가 없으면 nil 을 반환한다" do
      expect(helper.paint_assignees([])).to be_nil
    end
  end

  describe "#paint_labels" do
    it "라벨 목록을 포맷해서 반환한다" do
      result = helper.paint_labels([{ "name" => "bug", "color" => "ff0000" }])
      expect(result).to include("bug")
    end

    it "라벨이 없으면 nil 을 반환한다" do
      expect(helper.paint_labels([])).to be_nil
    end
  end
end
