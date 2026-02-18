# features

GitHub 이슈 기반 브랜치 워크플로우를 지원하는 Ruby CLI gem

브랜치 이름(`issue/1`, `issues/42`, `feature/3`)에서 이슈 번호를 해석해 GitHub 관련 정보를 처리한다.

## 요구사항

- Ruby >= 3.4
- [gh](https://cli.github.com) — GitHub CLI (`gh auth login` 필요)

## 설치

```bash
gem install features
```

또는 Gemfile:

```ruby
gem "features"
```

## 사용법

```bash
features info                # 현재 브랜치 연결 open 이슈 목록
features info --all          # open + closed 이슈 모두
features info --remote       # 원격 브랜치 포함
features issue_list          # 최근 open 이슈 목록
features clean               # closed 이슈 연결 로컬 브랜치 삭제
features githook             # starship 연동 git hook 설치
features init zsh            # zsh alias 설치
features env                 # 환경변수 출력 (디버깅)
```

### 브랜치 예시

```
issue/1      => #1 이슈
issue/2-fix  => #2 이슈
issues/42    => #42 이슈
feature/3    => #3 이슈
```

### Shell Alias 설치

```bash
echo 'eval "$(features init zsh)"' >> ~/.zshrc
source ~/.zshrc
features_aliases   # 등록된 alias 목록
```

| alias      | 설명                              |
|------------|-----------------------------------|
| `f`        | `features info --all`             |
| `fa`       | `features info --remote`          |
| `fsw`      | fzf로 브랜치 선택 후 switch       |
| `f_clean`  | closed 이슈 브랜치 삭제           |

## 개발

```bash
mise install      # ruby 3.4 설치
bin/setup         # bundle install

bin/t             # 테스트 실행
bin/t -c          # 테스트 + coverage
bin/console       # irb 콘솔
```

또는 mise 태스크:

```bash
mise run test     # 테스트
mise run build    # gem 빌드
```

## ENV

| 변수                  | 설명                          | 기본값 |
|-----------------------|-------------------------------|--------|
| `FEATURES_ISSUE_LIMIT` | 출력할 최대 이슈 수          | 100    |
| `DEBUG`               | `1` 설정 시 상세 에러 출력   | -      |
| `COVERAGE`            | `1` 설정 시 coverage 측정    | -      |
