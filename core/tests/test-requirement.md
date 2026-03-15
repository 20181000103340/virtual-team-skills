# 项目需求

## 基本信息
- 项目名称: SuggestImpactedStocks
- 项目路径: /root/worldmonitor
- 语言/框架: TypeScript / Vite / Vercel Edge Functions
- 测试框架: node --test (内置)
- 构建命令: npm run typecheck:api
- 测试命令: npm run test:data
- Lint 命令: npm run typecheck:api

## 需求描述
新增 `market/v1/suggest-impacted-stocks` RPC，输入一条新闻（标题/链接/正文），输出可能受影响的股票列表及解释。

采用两阶段架构：
1. Recall（召回）— 从 Watchlist 词典中快速匹配可能相关的股票（别名匹配 + 主题触发词 + 行业关键词）
2. Precision（精排）— LLM 单次批量判断候选股票的相关性、影响方向和理由

## 涉及模块
- 前端: 无（本需求纯后端）
- 后端: server/worldmonitor/market/v1/, proto/worldmonitor/market/v1/
- 共享: shared/stock-watchlist.json (新增)

## 验收标准
- [ ] proto 定义通过 `make generate`
- [ ] handler 通过 typecheck (`npm run typecheck:api`)
- [ ] 输入 "Apple reports record iPhone sales" → top1 命中 AAPL
- [ ] 输入 "OPEC announces production cut" → 返回能源股候选
- [ ] 输入 "Local sports team wins" → 返回空列表
- [ ] 短 ticker 不误报（"The MA program at Harvard" 不命中 MA）
- [ ] Redis 缓存键覆盖所有影响响应的参数
- [ ] 纳入 PREMIUM_RPC_PATHS
- [ ] 纳入 ENDPOINT_RATE_POLICIES (120/60s)

## 约束与注意事项
- 不要修改现有 RPC 的行为
- 不要修改 shared/stocks.json
- 复用现有 cachedFetchJson / callLlm / searchRecentStockHeadlines
- 遵循现有 handler 注册模式 (handler.ts + service.proto)

## 禁止操作
- 禁止修改 package-lock.json
- 禁止删除任何现有文件

## 覆盖率要求
- 关键路径测试: 必须覆盖 recall 引擎的三层匹配逻辑

## 参考资料
- 设计文档: docs/internal/news-to-stocks-design.md
