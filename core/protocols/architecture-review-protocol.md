# Phase 3: 架构评审会协议

## 阶段编号
Phase 3 → Gate 3

## 执行方式
3 个评审 agent 并行（并发数 = 3）

## 评审分工
| 评审者 | 评审对象 | 视角 |
|--------|---------|------|
| 前端架构师 | 后端方案 | 接口可用性、字段对齐 |
| 后端架构师 | 前端方案 | 数据流合理性 |
| 总架构师 | 整体 | 一致性、风险处理 |

## 严重级别
- blocker: 不修复则无法继续
- major: 应该修复但不阻塞
- minor: 建议改进

## 输入
- .team/arch/chief.md
- .team/arch/frontend.md
- .team/arch/backend.md

## 产出
- .team/review/arch-review-by-frontend.md
- .team/review/arch-review-by-backend.md
- .team/review/arch-review-by-chief.md
- .team/review/arch-review-summary.md（PM 汇总）

## Gate 3 出口条件
- [ ] 3 份评审报告存在
- [ ] blocker 数 = 0

## 定向修复
- blocker > 0 → 识别涉及角色 → 只重跑该角色的 Phase 2 agent
- 修复 prompt 注入评审问题清单
- 最多 2 轮

## 交互模式
--interactive: 评审汇总后暂停
