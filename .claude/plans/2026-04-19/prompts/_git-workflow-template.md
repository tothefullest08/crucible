# 공용 Git Workflow 템플릿 (세션 자체 커밋·푸시)

> 모든 후속 프롬프트에서 이 템플릿을 참조. 이전 프롬프트에서 발생한 **unstaged changes 에러** 및 **권한 재확인 반복** 문제 해결.

## ⚠️ 왜 `git pull --rebase`를 먼저?

**잘못된 순서 (구 템플릿)**:
```
1. sed로 체크박스 업데이트  →  working tree에 unstaged 변경 생김
2. git pull --rebase          →  ❌ "스테이징하지 않은 변경 사항" 에러
```

**올바른 순서 (신 템플릿)**:
```
1. git pull --rebase FIRST    →  working tree clean 유지
2. sed로 체크박스 업데이트    →  안전
3. git add + commit + push
```

## 📋 표준 워크플로우 템플릿

각 프롬프트의 "완료 후 자동 커밋+푸시" 블록은 다음 형태를 따를 것:

```bash
cd /Users/ethan/Desktop/personal/harness

# Step 1: pull --rebase FIRST — working tree가 clean한 상태에서 시작 (필수)
git pull --rebase origin main || { echo "pull failed, abort"; exit 1; }

# Step 2: 체크박스 업데이트 (sed — pull 완료 후라 안전)
sed -i '' \
  -e 's|^- \[ \] \*\*T-WX-YY\*\*|- [x] **T-WX-YY**|' \
  -e 's|^- \[ \] \*\*T-WX-ZZ\*\*|- [x] **T-WX-ZZ**|' \
  .claude/plans/2026-04-19/04-planning/implementation-plan.md

# Step 3: stage (본인 파일만 + implementation-plan.md)
git add <파일1> <파일2> ... .claude/plans/2026-04-19/04-planning/implementation-plan.md

# Step 4: commit (DCO sign-off 필수, -s 플래그)
git commit -s -m "$(cat <<'EOF'
feat(WX): 제목 한 줄

- 세부 변경 1
- 세부 변경 2
- 🚨 P0-N (해당 시)
- 체크박스 T-WX-YY·ZZ 업데이트
EOF
)"

# Step 5: push (재시도 3회, 재시도 시 rebase만)
for attempt in 1 2 3; do
  if git push origin main; then break; fi
  if [ "$attempt" -eq 3 ]; then
    echo "push failed 3x, manual intervention required"
    exit 1
  fi
  echo "push attempt $attempt failed, rebasing and retry..."
  git fetch origin main
  git rebase origin/main || { echo "rebase conflict, abort"; exit 1; }
done
```

## 🚨 중요 원칙

1. **pull → sed → add → commit → push** 순서 절대 엄수
2. sed로 수정하는 파일은 반드시 `git add` stage에 포함 (pull 이전 수정은 무효화됨)
3. push 실패 시 `git rebase origin/main`만 시도. working tree는 이미 커밋됐으므로 unstaged 이슈 없음
4. 3회 실패 시 abort + 사용자에게 수동 개입 요청

## 📝 파일 경합 대비 (다중 패널 병렬 시)

- 각 패널이 서로 다른 파일만 수정하도록 프롬프트 설계
- 공통 파일(`implementation-plan.md`)은 다른 줄만 수정 (체크박스 라인은 고유)
- 그럼에도 rebase 충돌 시: `git rebase --abort` + 수동 해결 요청

## 💡 권한 재확인 방지

`.claude/settings.local.json`에 `defaultMode: bypassPermissions` + broad allowlist 설정 완료. 세션 시작 시 bypass 모드 자동 적용. /clear 후에도 유지.
