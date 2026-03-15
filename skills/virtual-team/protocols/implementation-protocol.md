# Phase 5: 编码实现协议

## 阶段编号
Phase 5 → Gate 5

## 执行方式
前端开发 + 后端开发并行（并发数 = 2）

## 输入
- 需求文档
- .team/kickoff/brief-{role}.md
- .team/arch/{frontend|backend}.md
- .team/tasks/{frontend|backend}.md
- .team/tasks/interface-contract.md（只读）

## 子 agent 流程
1. 读取所有输入文件
2. 按任务清单逐项实现
3. 自测：构建命令（超时 300s）+ lint 命令（超时 300s）
4. 自测失败 → 自行修复（最多 2 轮）
5. 写实现报告

## 产出
- 实际代码文件
- .team/impl/frontend.md
- .team/impl/backend.md

## Gate 5 出口条件
- [ ] 前端实现报告中所有任务 [x]
- [ ] 后端实现报告中所有任务 [x]
- [ ] 构建命令 exit code = 0（超时 300s）
- [ ] lint 命令 exit code = 0（超时 300s）

## 并发安全
- 前后端任务清单中的文件路径不重叠（Phase 4 已验证）
- 接口契约只读
