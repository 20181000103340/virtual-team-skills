# Virtual Team Skill

多 agent 虚拟开发团队，输入结构化需求文档，自动完成从架构设计到测试交付的全流程。

## 支持平台

| 平台 | 执行开发流程 | 生成需求文档 |
|------|-------------|-------------|
| **Claude Code** | `/virtual-team requirement.md` | `/virtual-team-init` |
| **Codex CLI** | `codex "按照 virtual-team/SKILL.md 执行，需求文档: requirement.md"` | 不支持（无交互式对话） |

> **Codex 用户**：先在 Claude Code 中运行 `/virtual-team-init` 生成需求文档，再用 Codex 执行开发流程。

## 支持语言

TypeScript/JavaScript、Python、Go、Rust、Java/Kotlin、Ruby、C#/.NET、C/C++

## 支持架构模式

| 模式 | 说明 |
|------|------|
| `web-fullstack` | 前端 + 后端同仓 |
| `backend-api` | API 服务，无前端 |
| `cli-library` | CLI 工具或库 |
| `monolith` | 单体应用 |
| `ddd-layered` | DDD 领域驱动分层 |

## 快速开始

### 1. 准备需求文档

**方式 A：使用 init 向导（推荐）**

```bash
/virtual-team-init
```

交互式向导会自动检测项目语言、框架和架构模式，引导你逐步填写，最终生成 `requirement.md`。

**方式 B：手动填写模板**

复制 `protocols/requirement-template.md` 到项目目录，按模板填写。必填字段：

- 项目名称、路径、语言/框架
- 构建/测试/Lint 命令
- 需求描述、涉及模块、验收标准

### 2. 运行

```bash
# 全自动模式
/virtual-team path/to/requirement.md

# 交互模式（关键节点暂停确认）
/virtual-team path/to/requirement.md --interactive

# 从上次中断处继续
/virtual-team path/to/requirement.md --resume

# 强制从头重跑
/virtual-team path/to/requirement.md --force
```

### 3. 查看产出

所有中间产出和最终报告在 `.team/` 目录下。

## 8 个角色

| 角色 | 职责 | 是否子 agent |
|------|------|-------------|
| 项目管理员 (PM) | 编排调度、Gate 检查、修复循环 | 否（Orchestrator） |
| 总架构师 | 整体架构、模块划分、技术选型 | 是 |
| 前端架构师 | 组件设计、路由、状态管理 | 是 |
| 后端架构师 | API 设计、缓存策略、数据模型 | 是 |
| 前端开发工程师 | 前端编码实现 | 是 |
| 后端开发工程师 | 后端编码实现 | 是 |
| 前端测试工程师 | 前端测试编写与执行 | 是 |
| 后端测试工程师 | 后端测试编写与执行 | 是 |

## 9 个阶段

| 阶段 | 名称 | Gate |
|------|------|------|
| Phase 0 | 立项准备 | Gate 0 |
| Phase 1 | 项目启动会 | Gate 1 |
| Phase 2 | 架构设计 | Gate 2 |
| Phase 3 | 架构评审会 | Gate 3 |
| Phase 4 | 任务拆分 | Gate 4 |
| Phase 5 | 编码实现 | Gate 5 |
| Phase 6 | 测试验证 | Gate 6 |
| Phase 7 | 项目评审会 | Gate 7 |
| Phase 8 | 交付 | — |

## 安全限制

- 只执行需求文档中用户显式填写的命令
- 命令超时 300 秒
- 默认不 commit、不 push、不 deploy、不删文件
- 接口契约文件 Phase 4 后冻结

## 目录结构

```
virtual-team/
├── SKILL.md          # Claude Code 入口
├── README.md         # 本文件
├── DESIGN.md         # 设计文档
├── codex/            # Codex 配置
├── roles/            # 角色 system prompt
├── protocols/        # 阶段协议
├── templates/        # 产出物模板
└── tests/            # 验证测试
```

详细设计见 [DESIGN.md](DESIGN.md)。
