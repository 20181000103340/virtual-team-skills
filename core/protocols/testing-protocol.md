# Phase 6: 测试验证协议

## 阶段编号
Phase 6 → Gate 6

## 执行方式
前端测试 + 后端测试并行（并发数 = 2）

## 输入
- 需求文档（验收标准）
- .team/kickoff/brief-{role}.md
- .team/tasks/interface-contract.md
- .team/impl/{frontend|backend}.md
- .team/arch/{frontend|backend}.md

## 子 agent 流程
1. 读取验收标准和实现报告
2. 编写测试用例
3. 真实执行测试命令（Bash tool，超时 300s）
4. 收集结果：通过/失败/跳过/覆盖率
5. 对失败用例分析原因
6. 写测试报告

## 断言修改边界
- 允许：修复语法错误、import 路径、mock 数据
- 禁止：修改断言逻辑以降低验收标准
- 歧义：记录到报告，标注"需 PM 裁决"

## 产出
- 测试代码文件
- .team/test/frontend.md
- .team/test/backend.md

## Gate 6 出口条件
- [ ] 测试命令 exit code = 0（超时 300s）
- [ ] 失败用例数 = 0
- [ ] 覆盖率 >= 需求文档要求（或默认 60%）

## 定向修复循环
1. PM 汇总缺陷清单
2. 生成修复 prompt（注入缺陷 + lastErrorSummary）
3. 只重跑出问题的开发 agent
4. 开发修复 → 只重跑对应测试 agent
5. 重新检查 Gate 6（最多 3 轮）
6. 超限 → .team/blocked-report.md
