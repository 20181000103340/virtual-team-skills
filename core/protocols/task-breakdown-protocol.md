# Phase 4: 任务拆分协议

## 阶段编号
Phase 4 → Gate 4

## 执行者
PM（Orchestrator）

## 输入
- 通过评审的架构方案（3 份）
- 需求文档验收标准

## 流程
1. 读取三份架构方案
2. 拆分为前端/后端编码任务清单
3. 生成接口契约文件
4. 检查文件路径无重叠
5. 检查任务覆盖验收标准

## 产出
- .team/tasks/frontend.md
- .team/tasks/backend.md
- .team/tasks/interface-contract.md（生成后冻结，Phase 5/6 只读）

## Gate 4 出口条件
- [ ] .team/tasks/frontend.md 非空
- [ ] .team/tasks/backend.md 非空
- [ ] .team/tasks/interface-contract.md 非空
- [ ] 前后端文件路径无重叠
- [ ] 任务条目覆盖所有验收标准

## 冻结规则
interface-contract.md 在本阶段生成后冻结，后续阶段的 agent 只读不写。
