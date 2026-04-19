---
lens: vague
topic: 내부 관리자 대시보드 개편
date: 2026-04-19
decisions:
  - question: 우선 개편 대상
    decision: 주문 관리 화면
    reasoning: 월간 불만 1위 영역
stop_doing: []
open_questions: []
---

# 내부 관리자 대시보드 개편

## Goal

운영팀이 주문 이상을 더 빨리 발견하도록 대시보드를 개편한다.

## Scope

- Included: 주문 목록, 주문 상세, 취소/환불 플로우
- Excluded: 재고 관리, 정산, 고객 CS 채팅

## Constraints

- 현재 React + TanStack Query 스택 유지
- 기존 권한 체계 준수

## Success Criteria

- 운영팀이 잘 쓸 수 있게 한다
- 업무 효율이 개선되어야 함
- 불편함을 줄인다
