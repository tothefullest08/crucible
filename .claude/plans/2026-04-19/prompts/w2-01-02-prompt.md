# W2 Chain A — T-W2-01 + T-W2-02 (/brainstorm SKILL 구조 + clarify 3-lens 본문)

## 📖 필수 컨텍스트

1. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/INDEX.md`
2. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/03-design/final-spec.md` — v3.1 (§3.1·§3.2 I/O 계약, §3.5 6축 강제 범위, §4.3 보안)
3. `/Users/ethan/Desktop/personal/harness/.claude/plans/2026-04-19/04-planning/implementation-plan.md` §W2 — T-W2-01·02 정의
4. `/Users/ethan/Desktop/personal/harness/skills/using-harness/SKILL.md` (T-W1-05 산출물, 포맷 레퍼런스)
5. **레퍼런스** (read-only):
   - `/Users/ethan/Desktop/personal/harness/references/plugins-for-claude-natives/plugins/clarify/` 3-lens 원본 (vague/unknown/metamedium 각 SKILL.md)
   - `/Users/ethan/Desktop/personal/harness/references/compound-engineering-plugin/skills/ce-brainstorm/` CE brainstorm 9단 패턴

## 🎯 태스크 (순차)

### T-W2-01 — `skills/brainstorm/SKILL.md` 구조 + frontmatter (4h)

**경로**: `skills/brainstorm/SKILL.md`

**frontmatter 필수 필드** (CE `/ce-review` skill-frontmatter lint 기준):
```yaml
---
name: brainstorm
description: "요구사항 브레인스토밍 / Feature brainstorming — clarify 3-lens 내장"
when_to_use: "모호한 요구사항을 구체 스펙으로 정제할 때. 'brainstorm', '브레인스토밍', '요구사항 정리', 'spec this out' 등"
input: "주제 (자유 발화)"
output: ".claude/plans/YYYY-MM-DD-{slug}-requirements.md (slug 화이트리스트: [a-zA-Z0-9_-])"
---
```

- `description`은 T-W2-03에서 한·영 병기 세밀 조정 예정 (본 태스크는 1차 초안)
- `validate_prompt` 필드는 T-W2-05에서 추가 예정

**본문 구조 (스켈레톤, T-W2-02에서 채움)**:
- `# Brainstorm` 제목
- `## When to Use` (when_to_use frontmatter와 본문 연결)
- `## Protocol`
  - `### Phase 1: Intake` (주제 수신)
  - `### Phase 2: Clarify (3-lens)` — T-W2-02에서 채움
  - `### Phase 3: Synthesize`
  - `### Phase 4: Save Requirements` (T-W2-04 템플릿 참조)
- `## Integration Points` (→ `/plan` 이후)

**검증**: `yq eval 'has("name") and has("description")' skills/brainstorm/SKILL.md` 통과 + CE skill-frontmatter lint (간단 grep) 통과

---

### T-W2-02 — clarify 3-lens 본문 내장 (8h)

**목표**: clarify 플러그인(p4cn)의 3-lens (vague · unknown · metamedium)를 SKILL.md `### Phase 2: Clarify` 아래 내장. 포팅 자산 **#14** (synthesis 기준).

**Phase 2 본문 구성**:

#### Phase 2.1 — Lens 자동 선택 (≤ 100 words)
- vague: 요구사항이 모호할 때 (개방형 질문 → 가설 옵션 전환)
- unknown: 전략/계획의 숨은 가정·블라인드 스팟 발견
- metamedium: 내용(content) vs 형식(form) 재프레이밍

각 lens의 **트리거 키워드**:
- vague: "clarify", "요구사항 명확히", "spec this out", "scope"
- unknown: "known unknown", "blind spots", "뭘 모르는지", "가정 점검"
- metamedium: "내용 vs 형식", "metamedium", "새로운 포맷", "관점 전환"

AI가 주제 + 대화 맥락을 보고 3 중 하나 선택. 복수 해당 시 유저에게 단일 선택 제시.

#### Phase 2.2 — 3-Round Depth Pattern

모든 lens 공통 구조:

**R1 (3-4 질문)**: broad, 전체 4분면 / 주요 가설 검증. AskUserQuestion 도구로 batched.

**R2 (2-3 질문)**: weak spot drill-down. R1 답변 기반 재설계 (never pre-prepared).

**R3 (선택, 2-3 질문)**: execution detail. 필요 시만.

**Cap: 7-10 total questions**. 과도 시 fatigue.

#### Phase 2.3 — Lens별 특화

- **vague**: 가설 옵션 3-4개씩 제시, "Other" 자동 제공. 출력 = 정제된 요구사항 (ambiguity → concrete).
- **unknown**: Known/Unknown 4분면 매트릭스 시각화 (KK·KU·UK·UU + 60/25/10/5% 배분). "Stop Doing" 섹션 필수.
- **metamedium**: Alan Kay metamedium 개념 — content 최적화 vs form 전환 판단. "form-level alternatives" 2-3개 제시.

#### Phase 2.4 — 각 lens의 산출물 스키마

YAML frontmatter + Markdown 본문 조합. `output` 경로(`.claude/plans/YYYY-MM-DD-{slug}-requirements.md`)에 저장.

공통 frontmatter:
```yaml
---
lens: vague | unknown | metamedium
topic: <주제>
decisions: [list of decisions with reasoning]
stop_doing: [list]    # unknown lens 필수
---
```

### 포팅 주의사항

- **references/plugins-for-claude-natives/plugins/clarify/** 의 원본 SKILL.md 3개를 **그대로 복사 금지**
- **패턴·구조는 차용**, 본 플러그인의 frontmatter + Phase 명명 규약에 맞춰 **재작성**
- 원본 영어 프롬프트 → 본문은 영어 유지. 한·영 병기는 T-W2-03에서
- R1·R2·R3 batch 예시(3-4 질문) 각 lens마다 1개씩 내장

---

## 📁 산출물

- `skills/brainstorm/SKILL.md` (T-W2-01 + T-W2-02 통합, 예상 400~600 lines)

## ⚙️ 실행 제약

- **패널 B와 파일 충돌 없음**: 본 패널은 `skills/brainstorm/SKILL.md`만. 패널 B는 `skills/brainstorm/templates/` + `__tests__/security/fixtures/slug-injection/`.
- **한국어 설명 · 영어 frontmatter·본문 primary** (description 한·영 병기는 T-W2-03)
- **bash+jq만** (N/A for SKILL.md 본문)
- final-spec.md · implementation-plan.md(체크박스 제외) 수정 금지

## ✅ 완료 기준

1. SKILL.md frontmatter CE lint 통과
2. 3-lens 본문 각 lens마다 R1·R2·R3 패턴 재현 + 트리거 키워드 리스트 포함
3. 체크박스 T-W2-01·02 업데이트
4. 자체 커밋+푸시 완료

---

## 🔄 완료 후 자동 커밋+푸시

```bash
cd /Users/ethan/Desktop/personal/harness

# 1. 체크박스
sed -i '' \
  -e 's|^- \[ \] \*\*T-W2-01\*\*|- [x] **T-W2-01**|' \
  -e 's|^- \[ \] \*\*T-W2-02\*\*|- [x] **T-W2-02**|' \
  .claude/plans/2026-04-19/04-planning/implementation-plan.md

# 2. pull rebase
git pull --rebase origin main

# 3. stage (본인 영역만)
git add skills/brainstorm/SKILL.md .claude/plans/2026-04-19/04-planning/implementation-plan.md

# 4. commit (DCO sign-off)
git commit -s -m "$(cat <<'EOF'
feat(W2): T-W2-01·02 /brainstorm SKILL 구조 + clarify 3-lens 본문

- skills/brainstorm/SKILL.md frontmatter: name/description/when_to_use/input/output
- Phase 2 clarify 3-lens 내장: vague / unknown / metamedium
- 각 lens R1·R2·R3 depth pattern + 트리거 키워드 + 산출물 스키마
- 포팅 자산 #14 (p4cn clarify) 패턴 차용, 프론트매터 재작성
EOF
)"

# 5. push (재시도 3회)
git push origin main || (git pull --rebase origin main && git push origin main) || (git pull --rebase origin main && git push origin main)
```

## 🛑 금지

- `skills/brainstorm/templates/`, `__tests__/security/fixtures/slug-injection/` 건드리기 (패널 B 범위)
- `validate_prompt` 필드 추가 (T-W2-05 범위)
- T-W2-10 HARD-GATE 태그 배치 (다음 sprint)
- `skills/using-harness/`, `hooks/`, `scripts/`, `.claude-plugin/` 수정

시작하세요.
