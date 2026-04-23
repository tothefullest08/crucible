---
name: docs-skills-pair-omission
description: 새 스킬 추가 시 docs/skills/{name}.md + {name}.ko.md pair 생성을 빠뜨리지 말 것
type: correction
candidate_id: d03a2c22-feb9-463c-a61c-b29cb878f17d
promoted_at: 2026-04-22T00:00:00Z
evaluator_score: 0.82
source_turn: "feat/dogfood-logger:PR-5 post-review"
trigger: user_correction
original_claim: |
  v1.1.0 릴리스의 "문서 업데이트" 단계는 README.md · README.ko.md · AGENTS.md ·
  .claude-plugin/plugin.json 4건 수정으로 충분하다고 판단하고 Phase 6을 완료 처리했다.
user_correction: |
  "/Users/ethan/Desktop/personal/harness/docs/skills 에 설명이 빠진것같음"
  — docs/skills/ 는 스킬별 5-section 페이지(Paradigm · Judgment · Design Choices
  · Thresholds · References) 를 .md + .ko.md 쌍으로 유지하는 1차 산출물
  위치이며, 6번째 스킬 /crucible:log 에 대응하는 pair 생성이 누락됨을
  유저가 직접 지적.
prevention: |
  새 스킬 추가 작업의 "문서 업데이트" 단계에서 다음 체크리스트를 전부 통과할 것:
    [ ] skills/{name}/SKILL.md  (6 frontmatter 필드 + Protocol)
    [ ] .claude-plugin/plugin.json  (version bump + payload_sha256)
    [ ] README.md  ("Skills (N)" 카운트 + 본문 bullet)
    [ ] README.ko.md  ("N 스킬" 카운트 + 본문 bullet + docs/skills/ 링크 리스트)
    [ ] AGENTS.md  (Skill Compliance Checklist 섹션)
    [ ] docs/skills/{name}.md  (5-section 템플릿: Paradigm · Judgment ·
        Design Choices · Thresholds · References)
    [ ] docs/skills/{name}.ko.md  (5-section 템플릿 한국어판)
    [ ] __tests__/integration/test-{name}.sh + __tests__/fixtures/*

  추가 불변식 (grep-able 자기검증):
    - README.ko.md 의 docs/skills/ 링크 리스트 항목 수 ==
      ls docs/skills/*.ko.md | wc -l
    - ls docs/skills/*.md (non-ko) | wc -l ==
      ls docs/skills/*.ko.md | wc -l
    - 위 두 수치 == 스킬 디렉토리 수 (ls skills/ | wc -l,
      using-harness 제외)

  이 불변식 중 하나라도 깨지면 "문서 업데이트 미완료" 로 간주하고
  Phase 7 (커밋/PR) 로 넘어가지 말 것.
---

# docs/skills/ pair 누락 correction

## 맥락

- 작업: `/crucible:log` dogfooding 로거 스킬 추가 (v1.1.0)
- PR: #5 (feat/dogfood-logger)
- 시점: PR 생성 완료 직후, 유저 리뷰 단계

## 무엇이 틀렸나

새 스킬 추가 시 나는 "문서 업데이트" 의 범위를 **루트 레벨 파일** (README · AGENTS · plugin manifest) 로만 인식했다. 그러나 이 레포에서는 `docs/skills/` 하위가 **스킬별 심층 문서의 1차 저장소** 이며, 각 스킬은 `{name}.md` + `{name}.ko.md` 2개 페이지로 문서화된다 (Paradigm · Judgment · Design Choices · Thresholds · References 5 섹션 템플릿).

루트 README 의 bullet 은 "여기 더 자세한 설명이 있다" 의 요약/랜딩이고, docs/skills/ 페이지가 진짜 "설명" 이다. 5 스킬 → 6 스킬로 확장하면서 docs/skills/ 쌍은 5개 × 2 = 10개 그대로 남았다. 유저가 즉시 알아챈 이유.

## 재발 방지

frontmatter `prevention` 의 체크리스트 및 grep-able 불변식을 매 스킬 추가 시 통과시킬 것. PR 설명란 "변경 파일" 섹션이 체크리스트 항목을 순서대로 나열하는지도 2차 확인.

## 확인 명령 (레포 내부에서 실행)

```bash
# 스킬 수 (using-harness 는 런북이므로 제외)
skill_count=$(ls skills/ | grep -v '^using-harness$' | wc -l | tr -d ' ')
md_count=$(ls docs/skills/*.md | grep -v '\.ko\.md$' | wc -l | tr -d ' ')
ko_count=$(ls docs/skills/*.ko.md | wc -l | tr -d ' ')

echo "skills=$skill_count md=$md_count ko=$ko_count"
# 셋 다 같아야 PASS
```
