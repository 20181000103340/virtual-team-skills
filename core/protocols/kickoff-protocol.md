# Phase 1: 项目启动会协议

## 阶段编号
Phase 1 → Gate 1

## 执行者
PM（Orchestrator）

## 输入
- 需求文档（用户提供）
- .team/project-brief.md（Phase 0 产出）

## 流程
1. 读取需求文档和项目简报
2. 分析涉及模块、技术栈、风险点
3. 生成任务分派表 → .team/kickoff/assignment.md
4. 生成 Gate 门禁定义 → .team/kickoff/gates.md
5. 为 7 个角色生成任务书 → .team/kickoff/brief-{role}.md

## 产出
- .team/kickoff/assignment.md
- .team/kickoff/gates.md
- .team/kickoff/brief-chief-architect.md
- .team/kickoff/brief-frontend-architect.md
- .team/kickoff/brief-backend-architect.md
- .team/kickoff/brief-frontend-developer.md
- .team/kickoff/brief-backend-developer.md
- .team/kickoff/brief-frontend-tester.md
- .team/kickoff/brief-backend-tester.md

## Gate 1 出口条件
- [ ] assignment.md 存在
- [ ] gates.md 存在
- [ ] 7 份角色任务书全部存在

## 交互模式
--interactive: 完成后暂停，展示分派表，等待用户确认
Codex 降级: 写 .team/pause-required.md 后退出
