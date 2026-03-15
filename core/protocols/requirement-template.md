# 需求文档模板

> 本模板为虚拟团队的输入文档。用户需填写以下各节后提交给 `/virtual-team` 命令。

## 基本信息
- 项目名称: {name}
- 项目路径: {path}
- 语言/框架: {e.g. TypeScript / React / Vite}
- 测试框架: {e.g. vitest / playwright}
- 构建命令: {e.g. npm run build}
- 测试命令: {e.g. npm run test}
- Lint 命令: {e.g. npm run lint}

## 需求描述
{自然语言描述要做什么，越详细越好}

## 涉及模块
- 前端: {src/components/..., src/pages/...}
- 后端: {server/..., proto/...}
- 共享: {shared/...}

## 验收标准
- [ ] {具体的可测试条件 1}
- [ ] {具体的可测试条件 2}

## 约束与注意事项
- {不要改动的文件/模块}
- {必须兼容的现有功能}

## 禁止操作（可选）
- {e.g. 禁止修改 package-lock.json}

## 覆盖率要求（可选）
- 单元测试覆盖率: {e.g. 60%}
- 关键路径测试: {e.g. 必须覆盖}

## 参考资料（可选）
- {设计文档链接或路径}
