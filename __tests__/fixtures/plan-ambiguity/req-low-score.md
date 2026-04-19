---
lens: vague
topic: 회원 탈퇴 유예 기간 도입
date: 2026-04-19
decisions:
  - question: 유예 기간 길이
    decision: 30일
    reasoning: GDPR 참조
  - question: 재가입 시 데이터 복구
    decision: 이메일 + 동의 시 복구
    reasoning: 법무팀 검토 완료
stop_doing: []
open_questions: []
---

# 회원 탈퇴 유예 기간 도입

## Goal

회원이 탈퇴한 뒤에도 30일 내 복구할 수 있도록 유예 기간을 도입한다.

## Scope

- Included: 일반 회원, 기업 회원
- Excluded: 관리자 계정, API 전용 토큰 계정

## Constraints

- 개인정보 보관 기간은 법무 검토 기준 준수
- 기존 세션 토큰 즉시 만료

## Success Criteria

- 복구 요청 성공률 >= 95%
- 탈퇴 후 잔존 세션 유출 0건
- 개인정보 만료 자동화 100%
