# Phase 7: 项目评审会协议

## 阶段编号
Phase 7 → Gate 7

## 执行方式
3 个评审 agent 并行（并发数 = 3）

## 评审分工
| 评审者 | 视角 | 重点 |
|--------|------|------|
| 总架构师 | 代码质量 + 架构一致性 | 代码按架构实现、模块边界清晰、安全/性能 |
| 前端测试 | 前端质量 | 测试充分性、边界覆盖、用户体验 |
| 后端测试 | 后端质量 | 测试充分性、性能/安全、错误处理 |

## 输入
- .team/arch/*.md（架构方案）
- .team/impl/*.md（实现报告）
- .team/test/*.md（测试报告）
- 实际代码文件（Read 查看关键文件）

## 产出
- .team/review/project-review-by-chief.md
- .team/review/project-review-by-frontend-tester.md
- .team/review/project-review-by-backend-tester.md
- .team/review/project-review-summary.md（PM 汇总）

## Gate 7 出口条件
- [ ] 3 份评审报告存在
- [ ] blocker 数 = 0

## 定向修复
同架构评审：blocker > 0 → 定向修复 → 重测 → 重评审（最多 2 轮）
超限 → .team/blocked-report.md
