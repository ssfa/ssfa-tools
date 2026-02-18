# ssfa-tools

GitHub 이슈 기반 브랜치 워크플로우를 지원하는 Ruby 도구 모음 (mono repo)

## 프로젝트 구조

```
ssfa-tools/                  # mono repo 루트 (ruby 4.0.1)
├── mise.toml                # 루트 환경 설정 (monorepo_root)
├── .starship.toml           # starship 프롬프트 설정
└── features/                # features gem (ruby 3.4)
    ├── mise.toml            # features 환경 설정
    ├── exe/features         # 실행 파일
    ├── lib/features/        # 라이브러리
    │   ├── cli.rb           # Thor CLI 진입점
    │   └── github_helper.rb # GitHub / git 유틸리티
    └── spec/                # RSpec 테스트
```

## 요구사항

- [mise](https://mise.jdx.dev) — 다중 Ruby 버전 및 태스크 관리
- [gh](https://cli.github.com) — GitHub CLI
- [starship](https://starship.rs) — 프롬프트 (선택)

## 설치

```bash
git clone https://github.com/ssfa/ssfa-tools
cd features
mise install          # ruby 3.4 설치
bin/setup             # bundle install
```

## mise 환경

| 디렉토리    | Ruby   | 설명              |
|-------------|--------|-------------------|
| `ssfa-tools/` | 4.0.1 | mono repo 루트   |
| `features/`   | 3.4   | features gem     |

## 태스크

루트에서 `mise tasks --all` 로 전체 태스크 확인:

```bash
mise tasks --all
# //features:test    rspec 테스트 실행
# //features:build   gem 빌드
```

### 루트에서 실행

```bash
mise run //features:test     # 테스트
mise run //features:build    # 빌드
```

### features/ 에서 실행

```bash
cd features

mise run test      # 테스트
mise run build     # 빌드

bin/t              # 테스트 (shortcut)
bin/t -c           # 테스트 + coverage 측정
```

## features gem

브랜치 이름(`issue/1`, `issues/42`, `feature/3`)에서 GitHub 이슈 번호를 해석해 관련 정보를 출력하는 CLI 도구

```bash
features info           # 브랜치와 연결된 open 이슈 목록
features info --all     # open + closed 이슈 모두
features info --remote  # 원격 브랜치 포함
features issue_list     # 최근 open 이슈 목록
features clean          # closed 이슈 연결 로컬 브랜치 삭제
features githook        # starship 연동 git hook 설치
features init zsh       # zsh alias 설치
features env            # 현재 환경변수 출력 (디버깅)
```

### Shell Alias 설치

```bash
echo 'eval "$(features init zsh)"' >> ~/.zshrc
source ~/.zshrc
features_aliases        # 등록된 alias 목록 확인
```

## CI

`features/.github/workflows/ci.yml` — push / PR 시 자동 실행

| Job      | 내용               |
|----------|--------------------|
| RSpec    | 테스트 통과 여부   |
| Gem Build | `rake build` 빌드 가능 여부 |
