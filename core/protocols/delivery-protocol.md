# Phase 8: 交付协议

## 阶段编号
Phase 8（终止阶段）

## 执行者
PM（Orchestrator）

## 输入
- 所有 .team/ 产出物
- 实际代码变更

## 流程
1. 汇总所有产出物
2. 生成最终报告 → .team/final-report.md
3. 列出所有变更文件
4. 汇总测试结果和评审结论
5. 列出遗留问题和后续建议

## 产出
- .team/final-report.md

## 自动化边界
- 默认：不 commit、不 push、不 deploy
- 仅当需求文档明确授权 + --interactive 下用户确认时才执行 commit
- 永远不自动 push 或 deploy

## 完成标志
- .team/status.json 所有 Gate 状态为 passed
- .team/final-report.md 已生成
