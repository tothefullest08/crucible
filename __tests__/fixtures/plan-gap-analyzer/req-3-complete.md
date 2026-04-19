---
lens: vague
topic: 결제 실패 재시도 전략 설계
date: 2026-04-19
decisions:
  - question: 재시도 간격
    decision: 지수 백오프 (1·3·9분)
    reasoning: 토스 베스트 프랙티스 참조
  - question: 최대 재시도 횟수
    decision: 3회
    reasoning: 고객센터 CS 증가 방지
stop_doing: []
open_questions: []
---

# 결제 실패 재시도 전략 설계

## Goal

일시적 결제 실패로 인한 자동 이탈을 월 3% 미만으로 낮춘다.

## Scope

- Included: 토스페이먼츠 일반 결제, 정기 결제
- Excluded: 해외 PG, 현금영수증, 포인트 결제

## Constraints

- 재시도 총 지연 <= 15분
- 고객 알림은 Push 1회 + Email 1회만 허용
- 기존 결제 멱등성 키 재사용

## Success Criteria

- 결제 자동 복구율 >= 70%
- 고객센터 문의 증가율 < 5%
- P99 지연 < 15분
