# Codex Agent Rules v2

## 커밋 메시지 컨벤션

이 저장소(부모 모노레포)와 독립 서브모듈(`mobile`, `web`) 모두에 동일하게 적용한다.

### 기본 규칙

1. 제목(subject)과 본문(body) 사이는 반드시 빈 줄 하나로 분리한다.
2. 제목은 50자 이내로 작성한다.
3. 제목 첫 글자는 대문자로 시작한다.
4. 제목은 마침표로 끝내지 않는다.
5. 제목에는 명령형 동사를 사용한다 (예: `Add`, `Fix`, `Remove`).
6. 본문 각 줄은 72자 이내로 개행한다.
7. 본문에서는 **무엇을**이 아닌 **왜**를 설명한다.

### 구조

```text
<type>: <subject>

<body>

<footer>
```

제목은 필수다. 제목만으로 충분히 설명되는 경우 본문과 푸터는 생략할 수 있다.

### 타입

| 타입 | 사용 상황 |
|------|-----------|
| `feat` | 새로운 기능 또는 요구사항 충족을 위한 동작 변경 |
| `fix` | 버그 수정 |
| `build` | 빌드 시스템 또는 의존성 변경 |
| `chore` | 패키지 관리, `.gitignore` 등 기타 유지보수 |
| `ci` | CI 설정 변경 |
| `docs` | 문서 또는 주석 변경 |
| `style` | 로직 변경 없는 형식/스타일 수정 |
| `refactor` | 동작 변경 없는 리팩터링 |
| `test` | 테스트 추가 또는 수정 |
| `release` | 버전 릴리스 |

### 언어

`type`, 제목, 본문은 **영어**를 사용한다. 도구 호환성과 로그 일관성을 위함이다. 사람이 읽는 프로젝트 문서는 한국어를 사용할 수 있다.

---

## 서브모듈 업데이트 규칙

부모 레포에서 서브모듈 포인터를 업데이트할 때는 반드시 해당 서브모듈이 무엇을 변경했는지 명시한다.

```text
feat: Update mobile submodule — <변경 내용 요약>

<변경 이유 또는 영향 범위>
```

예시:
```text
feat: Update mobile submodule — session delete + details route map

Adds swipe-to-delete on Sessions tab and route map visualization
on the session detail screen.
```

---

## 브랜치 네이밍

| 패턴 | 사용 상황 |
|------|-----------|
| `feat/sprint-N-<description>` | 스프린트 기능 개발 |
| `fix/<description>` | 버그 수정 |
| `chore/<description>` | 유지보수 |

---

## AI 에이전트(Claude Code)를 위한 추가 지침

### 파일 작업 원칙

- `.pen` 파일은 Pencil MCP 도구로만 읽고 쓴다. `Read`/`Grep` 사용 금지.
- `web/supabase/migrations/`에 새 마이그레이션을 추가할 때는 기존 번호 순서를 반드시 확인 후 다음 번호를 부여한다.
- 서브모듈 내부 파일을 직접 수정하지 않는다. 서브모듈은 각자의 레포에서 독립적으로 관리된다.

### 코드 작성 원칙

- **주석 최소화**: 코드 자체가 설명되는 경우 주석 생략. `WHY`가 자명하지 않은 경우에만 한 줄 주석 허용.
- **보안**: SQL 인젝션, XSS, 커맨드 인젝션 등 OWASP Top 10 위험을 만들지 않는다.
- **최소 구현**: 현재 요구사항 이상의 추상화나 기능을 추가하지 않는다.
- **오프라인 퍼스트**: 모바일 기능 추가 시 오프라인 동작과 SQLite 저장을 기본으로 설계한다.

### Edge Function 작성 원칙

- 새 Edge Function은 `web/supabase/functions/<name>/index.ts` 위치에 생성한다.
- 공유 유틸리티는 `web/supabase/functions/_shared/`에 배치한다.
- 응답은 `_shared/response.ts`의 포맷터를 사용한다.
- 모든 함수는 `OPTIONS` 메서드(CORS preflight)를 처리해야 한다.

### 마이그레이션 작성 원칙

- 각 마이그레이션은 단일 목적이어야 한다 (테이블 생성, 정책 추가, RPC 함수 등을 혼합하지 않는다).
- RLS 정책은 반드시 `ENABLE ROW LEVEL SECURITY` 후에 추가한다.
- pg_cron 스케줄은 별도 마이그레이션 파일로 분리한다.
- 롤백이 불가능한 DDL(`DROP TABLE`, `DROP COLUMN`)은 별도로 명시하고 사용자 확인 후 실행한다.

### 응답 언어

모든 응답은 **한국어**로 작성한다.
