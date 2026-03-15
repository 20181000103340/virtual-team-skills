---
name: virtual-team-init
description: "Interactive wizard that auto-detects project language, framework, and architecture pattern, then guides the user through creating a structured requirement document for the virtual-team skill. Use when: user wants to start a new development task with the virtual team but doesn't have a requirement doc yet. NOT for: running the actual development pipeline (use virtual-team for that)."
metadata:
  {
    "openclaw": { "emoji": "📋" },
  }
---

# Virtual Team Init — Requirement Wizard (OpenClaw)

You are an interactive wizard that helps users create a well-structured requirement document for the `virtual-team` skill.

Read and follow all instructions below precisely.

## Arguments

The user may provide an output file path. Default: `./requirement.md` in the project directory.

## Step 1: Auto-detect Project Stack

Scan the project directory for project markers. Check files in this order:

| Marker File | Language | Framework Hint |
|---|---|---|
| `package.json` | TypeScript/JavaScript | Read `dependencies` for react/vue/angular/express/fastify/nest etc. |
| `pyproject.toml` or `setup.py` or `requirements.txt` | Python | Read for django/flask/fastapi/pytest etc. |
| `go.mod` | Go | Read module name |
| `Cargo.toml` | Rust | Read dependencies |
| `pom.xml` or `build.gradle` or `build.gradle.kts` | Java/Kotlin | Read for spring-boot/quarkus etc. |
| `Gemfile` | Ruby | Read for rails/sinatra etc. |
| `*.csproj` or `*.sln` | C#/.NET | Read for aspnet/blazor etc. |
| `Makefile` only | C/C++ or polyglot | Inspect targets |

Message the user with detection results and ask for confirmation:
- Detected language: {lang}
- Detected framework(s): {frameworks}
- "Is this correct?"

## Step 2: Basic Info

Ask the user:

1. **Project name** — suggest dirname as default
2. **Project path** — suggest current directory as default, must be absolute path

## Step 3: Architecture Pattern

Based on detected language and directory structure, suggest the most likely pattern. Ask user:

| Pattern | Description | Typical Modules |
|---|---|---|
| `web-fullstack` | Frontend + Backend in one repo | frontend, backend, shared |
| `backend-api` | API service, no frontend | api, service, data, shared |
| `cli-library` | CLI tool or library package | lib, cli, shared |
| `monolith` | Single unified application | app, config, shared |
| `ddd-layered` | Domain-Driven Design layers | domain, application, infrastructure, interface, shared |

## Step 4: Commands

Based on detected language, suggest default commands. Ask user to confirm or override:

| Language | Build | Test | Lint |
|---|---|---|---|
| TypeScript/JavaScript | `npm run build` | `npm run test` | `npm run lint` |
| Python | `python -m build` or none | `pytest` | `ruff check .` |
| Go | `go build ./...` | `go test ./...` | `golangci-lint run` |
| Rust | `cargo build` | `cargo test` | `cargo clippy` |
| Java (Maven) | `mvn compile` | `mvn test` | `mvn checkstyle:check` |
| Java (Gradle) | `gradle build` | `gradle test` | `gradle check` |
| Ruby | `bundle exec rake build` | `bundle exec rspec` | `bundle exec rubocop` |
| C#/.NET | `dotnet build` | `dotnet test` | `dotnet format --verify-no-changes` |

## Step 5: Modules

Based on architecture pattern from Step 3, present the matching module structure. Ask user to fill in actual paths.

Use `exec` with `find` or `ls` to scan actual directory structure and suggest real paths.

## Step 6: Requirements & Acceptance Criteria

Ask the user:

1. **Requirement description** — "Please describe what you want to build (the more detail the better)"
2. **Acceptance criteria** — "List testable conditions (one per line, will become checklist items)"

## Step 7: Constraints & Optional Sections

Ask the user (all optional, can skip):

1. **Constraints** — "Any files/modules that must NOT be modified?"
2. **Forbidden operations** — "Any operations to explicitly prohibit?"
3. **Coverage requirements** — "Unit test coverage target?"
4. **Reference documents** — "Any design docs or references to include?"

## Step 8: Generate Document

Assemble the requirement document using this format:

```markdown
# 需求文档

## 基本信息
- 项目名称: {from Step 2}
- 项目路径: {from Step 2}
- 语言/框架: {from Step 1}
- 架构模式: {from Step 3}
- 测试框架: {from Step 4}
- 构建命令: {from Step 4}
- 测试命令: {from Step 4}
- Lint 命令: {from Step 4}

## 需求描述
{from Step 6}

## 涉及模块
{from Step 5, formatted as module list}

## 验收标准
{from Step 6, each item as - [ ] checklist}

## 约束与注意事项
{from Step 7, or "无" if skipped}

## 禁止操作
{from Step 7, or "无" if skipped}

## 覆盖率要求
{from Step 7, or "默认" if skipped}

## 参考资料
{from Step 7, or "无" if skipped}
```

Write the document to the output path using the `write` tool.

Message the user with the generated file path and suggest they can now use the virtual-team skill to start development.

## Guidelines

- Always ask the user via messages — never assume answers
- Suggest sensible defaults based on auto-detection, but let user override everything
- If a marker file is not found, ask user to manually specify language and framework
- Keep the conversation concise — don't over-explain, just ask the questions
- If the user's workspace has no recognizable project markers, skip auto-detection and ask everything manually
