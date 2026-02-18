module Features
  module GithubHelper
    LIMIT = 100
    SIZE_PER_CALL = 25

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
        #{Rainbow("##{issue[:number]}").green} #{issue[:title]}#{paint_labels(issue[:labels])}#{paint_assignees(issue[:assignees])}#{if state
                                                                                                                                       paint_state(issue[:state])
                                                                                                                                     end}
      TITLE
    end

    def default_limit = (ENV["FEATURES_ISSUE_LIMIT"] || LIMIT).to_i

    def find_issues(issue_numbers = [], state: "all", limit: default_limit)
      logic = lambda do |numbers, size_per_call|
        cmds = begin
          open_cmd, closed_cmd = %w[open closed].map do
            %(gh issue list -s #{it} --search "is:issue #{numbers * " "}" -L #{size_per_call} --json number,title,labels,assignees,state 2> /dev/null)
          end
          case state
          when "open" then [open_cmd]
          when "closed" then [closed_cmd]
          else
            [open_cmd, closed_cmd]
          end
        end

        cmds.map { `#{it}` }
            .map { JSON.parse(it) }
            .map { it.to_h { |i| [i["number"].to_s, i.transform_keys { |j| j.to_sym }] } }
            .inject(:merge)
      end

      if issue_numbers.empty?
        logic.call([], limit)
      else
        Array(issue_numbers).uniq.take(limit.to_i).each_slice(SIZE_PER_CALL).map do |numbers|
          logic.call(numbers, SIZE_PER_CALL)
        end.inject({}) { |m, o| m.merge(o) }
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
      `git branch --show-current`
        .lines.map(&:strip)
        .tap(&method(:load_issues_from_branches))
        .map { |branch| issues[issue_num_from_branch(branch)] }
        .map { |issue| make_title(issue) }.first
      en
    end
  end
end
