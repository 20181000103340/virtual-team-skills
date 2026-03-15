# Phase 2: 架构设计协议

## 阶段编号
Phase 2 → Gate 2

## 执行方式
Step 2a: 总架构师单独执行（并发数 = 1）
Step 2b: 前端架构师 + 后端架构师并行（并发数 = 2）

## 输入
- 需求文档
- .team/kickoff/brief-{role}.md（各角色任务书）
- 项目源代码（Glob/Grep/Read 探索）

## 流程
1. PM 启动总架构师 agent
2. 总架构师完成后，PM 启动前端/后端架构师（并行）
3. 前端/后端架构师读取总架构方案后开始设计
4. PM 检查 Gate 2

## 产出
- .team/arch/chief.md（总架构方案）
- .team/arch/frontend.md（前端架构方案）
- .team/arch/backend.md（后端架构方案）

## Gate 2 出口条件
- [ ] .team/arch/chief.md 存在且非空
- [ ] .team/arch/frontend.md 存在且非空
- [ ] .team/arch/backend.md 存在且非空
- [ ] 接口名称交叉比对无遗漏
