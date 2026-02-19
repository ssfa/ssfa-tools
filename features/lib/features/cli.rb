require "thor"
require "pathname"
require "rainbow"
require "retryable"
require "erb"
require_relative "github_helper"

module Features

  class Cli < Thor
    include GithubHelper

    remove_command(*GithubHelper.instance_methods)

    Error = Class.new(StandardError)

    attr_accessor :issues

    desc "env", "디버깅용으로, 환경을 출력 한다."

    def env
      ruby_env = {
        RUBY_VERSION: RUBY_VERSION,
        RUBY_PLATFORM: RUBY_PLATFORM,
        RUBY_ENGINE: RUBY_ENGINE
      }
      key_length = ENV.keys.max_by { |i| i.size }.size
      ENV.to_h.merge(ruby_env)
         .to_a.sort_by { |i| i.to_s }.each { |k, v| puts "#{Rainbow(k.to_s.rjust(key_length + 2)).green}: #{v}" }
    end

    desc "info [limit]", "브랜치와 관련 이슈를 출력한다. 기본값: open 이슈만 출력 (limit 혹은 env FEATURES_ISSUE_LIMIT 로 최대 숫자 조정)"
    option :remote, type: :boolean, desc: "원격의 브랜치 포함"
    option :all, type: :boolean, desc: "open, close 모든 이슈 출력한다."
    option :close, type: :boolean, desc: "close 된 이슈만 룰력한다."

    def info(limit = default_limit)
      state =
        case
        when options[:all] then "all"
        when options[:closed] then "closed"
        else "open"
        end

      cmd(%Q(git branch#{" -a" if options[:remote]}))
        .lines.map(&:strip)
        .select { issue_num_from_branch it }
        .tap { |branches| load_issues_from_branches(branches, state:) }
        .map { |branch| [issues[issue_num_from_branch(branch)], branch.gsub(/^remotes\/origin\//, "")] }
        .select { |issue, _| issue }
        .take(limit.to_i)
        .then { |o| o.size == 0 ? nil : o }
        &.tap do |o|
        max = o.max_by { |_, i| i.size }.first.size
        o.map { |issue, branch| "#{Rainbow(branch.rjust max).yellow} #{make_title(issue)}".strip }.each { |i| puts i }
      end
    end

    desc "clean", "closed 된 연관 로컬 브랜치를 삭제한다."

    def clean
      branches = cmd("git branch")
                   .lines.map(&:strip).tap(&method(:load_issues_from_branches))
                   .map { |branch| [branch, issues[issue_num_from_branch(branch)]] }
                   .select { |_, v| v && v[:state] == "CLOSED" }

      puts "정리할 로컬 브랜치가 없습니다." or exit 1 if branches.empty?

      branches.each { |branch, issue| puts "    #{Rainbow(branch.rstrip).yellow} #{make_title(issue)}" }

      if !branches.empty? && ask("\n위에 모든 로컬 브랜치를 삭제할까요?", limited_to: %w(y n)) == "y"
        branches.each do |branch, issue|
          puts "삭제 => #{branch} #{make_title(issue)}"
          cmd("git branch -D #{branch}", verbose: true)
        end
      end
    end

    desc "init [zsh,bash]", "shell 환경에 맞는 alias 소스를 출력한다."
    long_desc <<~LONG_DESC
      쉘에 features 를 편하게 사용하는 헬퍼를 설치한다.

      Dependencies : fzf

      Install:
      \x5    eval "$(features init zsh)"

      USAGE:
      \x5    features_aliases
      \x5    f
      \x5    fa
      \x5    fsw
    LONG_DESC

    def init(shell = nil)
      puts <<~BASH unless shell
        #.zshrc, .bashrc 에 다음 라인을 추가한다.
        eval "$(features init zsh)"
      BASH
      exit 0 unless %w[zsh bash -].include?(shell)

      bash_script = <<~SHELL
        command -v f > /dev/null   || alias f='features info --all $@'
        command -v fa > /dev/null  || alias fa="features info --remote $@"
        command -v fl > /dev/null  || alias fl="features issue_list $@"
        command -v fsw > /dev/null || alias fsw="git switch \\`features info | fzf --ansi -q open | head -1 | awk '{print \\$1}'\\`"
        command -v ft > /dev/null  || alias ft="features current_issue_title | sed -E 's/ open$//' | sed -E 's/^/🔀 /' | tr -d '\\n' | pbcopy"
        command -v fm > /dev/null  || alias fm="features info && ft && git switch main && git merge - && git commit -am \\"\\`pbpaste\\`\\" # 머지하기 (fm)"

        command -v f_title > /dev/null     || alias ft="features current_issue_title | sed -E 's/ open$//' | sed -E 's/^/🔀 /' | tr -d '\\n' | pbcopy # 머지할 제목 출력(ft)"
        command -v f_switch > /dev/null    || alias f_switch="git switch \\`features info | fzf --ansi -q open | head -1 | awk '{print \\$1}'\\`"
        command -v f_create_pr > /dev/null || alias f_create_pr="gh pr create -a '@me' -t \\"\\`features current_issue_title\\`\\" # pr 생성 (fpr)"
        command -v f_clean > /dev/null     || alias f_clean="features clean"
        command -v f_merge > /dev/null     || alias f_merge="features info && ft && git switch main && git merge - && git commit -am \\"\\`pbpaste\\`\\" # 머지하기 (fm)"

        fn f_list_aliases() { alias | grep "$*" --color=never | sed -e 's/alias //' -e "s/=/::/" -e "s/'//g" | awk -F "::" '{ printf "\\033[1;36m%15s  \\033[2;37m=>\\033[0m  %-8s\\n",$1,$2}'; }
        fn features_aliaes(){ f_list_aliases features }
      SHELL

      erb = RUBY_VERSION =~ /^2.(4|5)/ ? ERB.new(bash_script, nil, "-") : ERB.new(bash_script, trim_mode: "-")
      puts erb.result(binding)
    end

    desc "save_issue_title", ".issue_title 에 이슈 제목을 저장한다."

    def save_issue_title = File.open(issue_title_path, "w") { |f| f.write issue_title }

    desc "current_issue_title", "issue_title 을 출력한다."

    def current_issue_title = puts(issue_title(state: false, assignees: false, labels: false))

    desc "githook", "프롬프트에 작업 중인 이슈 제목을 노출하는 기능을 설치한다."
    option :remove, aliases: "-r", type: :boolean, desc: "git hook 을 지운다."
    option :remove_all, aliases: "-m", type: :boolean, desc: "git hook 과 관련한 모든 파일을 삭제한다."
    option :quite, aliases: "-q", type: :boolean, desc: "덮어쓰기 경고는 출력하지 않는다."
    long_desc <<~LONG_DESC
      프롬프트에 작업 중인 이슈 제목을 노출하는 기능을 설치한다.

      Dependencies: gh cli, starship

      How To:
      \x5  • mise [env] 에서 STARSHIP_CONFIG (starship.toml) 설정
      \x5  • starship 프롬프트에서 .issue_title 내용을 읽어서 이슈 제목 노출
      \x5  • .git/hook/post-checkout 에서 브랜치 변경시 features save_issue_title 을 호출
    LONG_DESC

    def githook
      hook_cmd = "\nfeatures save_issue_title"
      starship = git_root / ".starship.toml"
      post_checkout = git_root / ".git/hooks/post-checkout"

      # validate
      (STDERR.puts Rainbow("- starship 환경이 아닙니다.").red or exit 1) if ENV["STARSHIP_SHELL"].nil?
      (STDERR.puts Rainbow("- git 프로젝트를 찾을수 없습니다.").red or exit 1) if git_root.nil?

      # remove
      if (options[:remove] || options[:remove_all]) && post_checkout.exist?
        puts Rainbow("✗ .git/hooks/post-checkout Uninstalled").red
        post_checkout.read.tap { |c| File.open(post_checkout, "w") { |f| f.write c.sub(hook_cmd, "") } }
      end

      if options[:remove_all]
        puts Rainbow("✗ .startship.toml deleted").red
        FileUtils.rm_f starship

        puts Rainbow("✗ .issue_title deleted").red
        FileUtils.rm_f issue_title_path
      end

      exit unless options.slice("remove_all", "remove").empty?

      # install
      if starship.exist?
        STDERR.puts Rainbow("- .starship.toml 파일이 존재합니다.").red unless options[:quite]
      else
        puts Rainbow("✔ .starship.toml Installed").green
        File.open(starship, "w") { |f| f.write <<~TOML }
          [custom.issue_title]
          format = "\\n[$output]($style)"
          command = "cat $(git rev-parse --show-toplevel)/.issue_title"
          when = "test -s $(git rev-parse --show-toplevel)/.issue_title"
          style = ""
        TOML
      end

      if post_checkout.exist? && post_checkout.read.include?(hook_cmd)
        STDERR.puts Rainbow("- git hook은 이미 설치되어 있습니다.").red unless options[:quite]
      else
        File.open(post_checkout, "a") { |f| f.write(hook_cmd) }
        FileUtils.chmod("+x", post_checkout)
        puts Rainbow("✔ .git/hooks/post-checkout Installed").green
      end

      if !issue_title_path.exist? || issue_title_path.read.strip.empty?
        puts Rainbow("✔ save .issue_title").green unless options[:quite]
        save_issue_title
      end
    end

    desc "issue_list [limit]", "gh i list 에서 페이저 제거 최근 이슈 출력, limit 혹은 env FEATURES_ISSUE_LIMIT 로 최대 숫자 조정"

    def issue_list(limit = default_limit)
      count = find_issues(state: "open", limit: limit.to_i).each { |_, issue| puts make_title(issue, state: false) }.count
      puts "Open 이슈 요약은 #{limit}개 까지만 출력합니다. ( env FEATURES_ISSUE_LIMIT 을 조종하세요. )" if count == limit
    end

  end

  module_function

  def run_cli

    puts <<~HELP if ARGV.empty? || ARGV == ["help"]
      features

      용도
          브랜치 이름 issue/숫자, feature/숫자 해석해서 gh 를 이용해서 github
          관련 정보를 처리한다. (복수형도 대응)

      브랜치 예제)
          issue/1    => 1번 이슈
          issue/2-ab => 2번 이슈
          issues/42  => 42번 이슈

      USAGE
          features help info
          features help clean
          features help githook

      SHELL Alias
          echo 'eval "$(features init zsh)"' >> ~/.zshrc
          . ~/.zshrc
          features_aliases

      ENV
         FEATURES_ISSUE_LIMIT : issue_list 에서 출력되는 최대 수
    HELP
    Features::Cli.start
  rescue Features::Cli::Error => e
    warn "ERROR: #{e.message}"
    exit 1
  rescue StandardError
    warn <<~ERROR_MESSAGE
      Trouble shooting:
        1. 이슈가 존재하는지 확인해주세요.
        2. github 로그인 되어 있지 않다면, 다음을 실행하세요.#{' '}
          gh auth login
        3. DEBUG=1 과 함께 실행하면 에러가 자세히 출력됩니다. ( 예 - DEBUG=1 features current_issue_title )
    ERROR_MESSAGE

    raise $! unless ENV["DEBUG"].nil?

  end
end

Features.run_cli unless defined?(RSpec)
