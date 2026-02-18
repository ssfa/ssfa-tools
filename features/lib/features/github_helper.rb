require "pathname"
require "json"
require "rainbow"
require "open3"

module Features
  module GithubHelper
    LIMIT = 100
    SIZE_PER_CALL = 25

    attr_accessor :last_cmd, :last_stdout, :last_stderr

    # 모든 다양한 에러를 잡아서 예외 처리 내용을 컬러링해서 출력한다.
    def cmd(command, debug: !ENV['DEBUG'].nil?, verbose: false)
      puts Rainbow(command).yellow if debug || verbose
      @last_stdout, @last_stderr, _ = Open3.capture3(@last_cmd = command)
      last_stdout.tap do
        puts last_stdout if debug
        warn Rainbow(last_stderr).red if last_stderr&.size&.> 0
      end
    end

    def paint_assignees(assignees)
      assignees ||= []
      " #{assignees.map { |i| Rainbow("@#{i["login"]}").cyan } * ","}" unless assignees.empty?
    end

    def paint_labels(labels)
      labels ||= []
      " [#{labels.map { |l| Rainbow(l["name"]).color(l["color"]) } * ","}]" unless labels.empty?
    end

    def paint_state(state) = state.gsub("OPEN", Rainbow(" open").green).gsub("CLOSED", Rainbow(" closed").red)

    def make_title(issue, state: true)
      issue && <<~TITLE.strip
        #{Rainbow("##{issue[:number]}").green} #{issue[:title]}#{paint_labels(issue[:labels])}#{paint_assignees(issue[:assignees])}#{
        if state
          paint_state(issue[:state])
        end}
      TITLE
    end

    def default_limit = (ENV["FEATURES_ISSUE_LIMIT"] || LIMIT).to_i

    # @param state "open", "closed", "all"
    def find_issues(issue_numbers = [], state: "all", limit: default_limit)
      logic = lambda do |numbers, size_per_call|
        [cmd(%(gh issue list -s #{state} --search "is:issue #{numbers * " "}" -L #{size_per_call} --json number,title,labels,assignees,state))]
          .map { JSON.parse(it) }
          .map { it.to_h { |i| [i["number"].to_s, i.transform_keys(&:to_sym)] } }
          .inject(:merge)
      end

      if issue_numbers.empty?
        logic.call([], limit)
      else
        Array(issue_numbers).uniq.take(limit.to_i).each_slice(SIZE_PER_CALL)
                            .map { |numbers| logic.call(numbers, SIZE_PER_CALL) }
                            .inject({}) { |m, o| m.merge(o) }
      end
    end

    def issue_num_from_branch(branch)
      %r{(feature|issue)(|s)/(?<issue_num>\d+)} =~ branch
      issue_num
    end

    def load_issues_from_branches(branches, state: "all")
      issue_numbers = branches.map(&method(:issue_num_from_branch)).compact
      self.issues = find_issues(issue_numbers, state: state)
    end

    def git_root = @git_root ||= Pathname.new(".").expand_path.ascend.find { |i| i && (i / ".git").exist? }

    def issue_title_path = @issue_title_path ||= git_root / ".issue_title"

    def issue_title
      cmd("git branch --show-current")
        .lines.map(&:strip)
        .tap(&method(:load_issues_from_branches))
        .map { |branch| issues[issue_num_from_branch(branch)] }
        .map { |issue| make_title(issue) }.first
    end

  end
end
