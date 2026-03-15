# `SuggestImpactedStocks` RPC 设计文档

日期：2026-03-15
状态：Final（合并 review 意见后终版）

---

## 1. 概述

新增 `market/v1/suggest-impacted-stocks` RPC，输入一条新闻，输出可能受影响的股票列表及解释。

采用**两阶段**架构：
1. **Recall（召回）** — 从候选集中快速匹配可能相关的股票
2. **Precision（精排）** — LLM 单次批量判断 + 可选 headlines 验证

先实现**路线 A（Watchlist 优先）**，后续增量升级到**路线 B（全市场召回）**。

### 设计约束

- **纳入 Premium 规格**：该 RPC 触发 LLM 调用，加入 `PREMIUM_RPC_PATHS`，强制 API key
- **精排分轻重两档**：LLM 精排是必须的；额外验证优先使用 `searchRecentStockHeadlines()`（轻量），`analyzeStock()` 保留为可选但默认关闭（cache miss 时会触发二次 LLM，仅在缓存命中率高的场景有价值）
- **空结果策略**：不相关新闻（体育/娱乐）必须返回空列表，不返回低分候选

---

## 2. Proto 定义

### 2.1 新增文件

```
proto/worldmonitor/market/v1/suggest_impacted_stocks.proto
```

### 2.2 消息定义

```protobuf
syntax = "proto3";

package worldmonitor.market.v1;

import "buf/validate/validate.proto";
import "sebuf/http/annotations.proto";
import "worldmonitor/market/v1/analyze_stock.proto";

message SuggestImpactedStocksRequest {
  // 新闻标题（必填）
  string title = 1 [
    (buf.validate.field).required = true,
    (buf.validate.field).string.max_len = 280
  ];
  // 新闻链接（可选）
  string url = 2;
  // 新闻正文/摘要（可选，提升召回质量）
  // NOTE: 长度限制在 handler 层做裁剪（MAX_CONTENT_LEN），不在 proto validate 层限制，
  //       以免影响后续全文分析场景。
  string content = 3;
  // 语言（可选），默认 en
  // NOTE: POST RPC 不使用 (sebuf.http.query) 注解，与仓库现有 batch POST 风格一致。
  string lang = 4;
  // 站点变体（可选），默认 finance
  string variant = 5;
  // 召回范围
  StockUniverse universe = 6;
  // 召回阶段最大候选数，默认 30
  int32 max_candidates = 7 [
    (buf.validate.field).int32.gte = 1,
    (buf.validate.field).int32.lte = 100
  ];
  // 最终返回 topK，默认 10
  int32 top_k = 8 [
    (buf.validate.field).int32.gte = 1,
    (buf.validate.field).int32.lte = 50
  ];
  // 是否包含 evidence 详情，默认 true
  bool include_evidence = 9;
  // 是否为候选补充"相关新闻标题证据"（来自现有 stock-news-search），默认 false
  bool include_stock_news_headlines = 10;
  // 是否对 topK 调用 analyzeStock（默认 false，不推荐高频使用）
  // NOTE: analyzeStock cache miss 时会触发 Yahoo History + LLM overlay，成本高。
  //       仅在缓存命中率高的场景（热门股票）有价值。
  bool include_analyze_stock = 11;
}

enum StockUniverse {
  STOCK_UNIVERSE_UNSPECIFIED = 0;
  // 只在自选股/预定义列表中匹配
  STOCK_UNIVERSE_WATCHLIST = 1;
  // 全市场召回（Phase 2）
  STOCK_UNIVERSE_GLOBAL = 2;
}

message SuggestImpactedStocksResponse {
  repeated ImpactedStock items = 1;
  // 处理耗时（毫秒）
  int32 elapsed_ms = 2;
  // 召回来源统计
  string recall_source = 3;
  string generated_at = 4;
  // LLM 溯源信息（排障用）
  string llm_provider = 5;
  string llm_model = 6;
  bool llm_fallback = 7;
}

message ImpactedStock {
  string symbol = 1;
  string name = 2;
  // 综合得分 0-1
  double score = 3;
  // 影响方向
  ImpactDirection direction = 4;
  // 影响理由（短句）
  repeated string reasons = 5;
  // 命中证据
  repeated ImpactEvidence evidence = 6;
  // 可选：内嵌 AnalyzeStockResponse（仅当 include_analyze_stock=true 时填充）
  AnalyzeStockResponse analysis = 7;
}

enum ImpactDirection {
  IMPACT_DIRECTION_UNKNOWN = 0;
  IMPACT_DIRECTION_BULLISH = 1;
  IMPACT_DIRECTION_BEARISH = 2;
  IMPACT_DIRECTION_NEUTRAL = 3;
}

message ImpactEvidence {
  // 证据类型（使用 enum 避免拼写漂移）
  ImpactEvidenceType type = 1;
  // 命中的关键词或规则名
  string matched_term = 2;
  // 置信度 0-1
  double confidence = 3;
  // 相关新闻标题（来自 stock-news-search）
  string headline = 4;
  // 相关新闻链接
  string headline_link = 5;
}

enum ImpactEvidenceType {
  IMPACT_EVIDENCE_TYPE_UNSPECIFIED = 0;
  IMPACT_EVIDENCE_TYPE_ALIAS_MATCH = 1;
  IMPACT_EVIDENCE_TYPE_THEME_TRIGGER = 2;
  IMPACT_EVIDENCE_TYPE_KEYWORD_MATCH = 3;
  IMPACT_EVIDENCE_TYPE_LLM_JUDGEMENT = 4;
  IMPACT_EVIDENCE_TYPE_NEWS_HEADLINE = 5;
}
```

### 2.3 注册到 service.proto

在 `proto/worldmonitor/market/v1/service.proto` 中新增：

```protobuf
import "worldmonitor/market/v1/suggest_impacted_stocks.proto";

// ... 在 service MarketService 内新增：

// SuggestImpactedStocks evaluates a news item and returns potentially impacted stocks.
rpc SuggestImpactedStocks(SuggestImpactedStocksRequest) returns (SuggestImpactedStocksResponse) {
  option (sebuf.http.config) = {path: "/suggest-impacted-stocks", method: HTTP_METHOD_POST};
}
```

使用 **POST** 而非 GET，因为 request body 可能包含较长的 `content` 字段。

### 2.4 Gateway 配置

在 `server/gateway.ts` 中：

**缓存层级**（`RPC_CACHE_TIER`）：
```typescript
'/api/market/v1/suggest-impacted-stocks': 'slow',  // 30min s-maxage
// NOTE: Vercel/CDN 通常不缓存 POST 响应，此 tier 仅保持一致性。
//       实际缓存以 Redis (cachedFetchJson) 为主。
```

**Premium 保护**（`PREMIUM_RPC_PATHS`）：
```typescript
const PREMIUM_RPC_PATHS = new Set([
  '/api/market/v1/analyze-stock',
  '/api/market/v1/get-stock-analysis-history',
  '/api/market/v1/backtest-stock',
  '/api/market/v1/list-stored-stock-backtests',
  '/api/market/v1/suggest-impacted-stocks',  // 新增
]);
```

**Endpoint 限流**（`server/_shared/rate-limit.ts` 的 `ENDPOINT_RATE_POLICIES`）：
```typescript
'/api/market/v1/suggest-impacted-stocks': { limit: 120, window: '60 s' },
```

---

## 3. Watchlist 词典设计

### 3.1 文件位置

```
shared/stock-watchlist.json
```

### 3.2 数据结构

```jsonc
{
  "version": 1,
  "stocks": [
    {
      "symbol": "AAPL",
      "name": "Apple",
      "display": "AAPL",
      // 别名：公司全称、品牌名、产品名、中文名等
      "aliases": ["Apple Inc", "苹果", "iPhone", "iPad", "Mac", "App Store"],
      // 所属行业 ETF（映射到 shared/sectors.json）
      "sectors": ["XLK"],
      // 主题关键词（用于低权重关键词匹配）
      "keywords": ["consumer electronics", "smartphone", "app ecosystem"],
      // 是否为短 ticker（<=4 字符），加载时自动计算，用于边界匹配策略
      "shortTicker": false
    },
    {
      "symbol": "V",
      "name": "Visa",
      "display": "V",
      "aliases": ["Visa Inc"],
      "sectors": ["XLF"],
      "keywords": ["payment", "credit card", "fintech"],
      "shortTicker": true  // 1 字母，必须使用单词边界匹配
    },
    {
      "symbol": "NVDA",
      "name": "NVIDIA",
      "display": "NVDA",
      "aliases": ["NVIDIA Corp", "英伟达", "GeForce", "CUDA", "H100", "A100", "Blackwell"],
      "sectors": ["XLK", "SMH"],
      "keywords": ["GPU", "AI chip", "data center", "artificial intelligence", "semiconductor"],
      "shortTicker": false
    }
    // ... 扩展到 ~200 只核心股票
  ],
  // 行业/主题触发（宏观新闻触发）
  // 数组结构，加载时预编译 regex 并附带权重
  "thematic_triggers": [
    { "pattern": "oil|crude|brent|opec", "weight": 0.6, "symbols": ["XOM", "CVX", "SLB", "COP", "BP"] },
    { "pattern": "rate hike|interest rate|fed|fomc|cpi|inflation", "weight": 0.6, "symbols": ["JPM", "BAC", "GS", "MS", "WFC"] },
    { "pattern": "semiconductor|chip|wafer|foundry|fab", "weight": 0.6, "symbols": ["NVDA", "TSM", "AVGO", "AMD", "INTC", "ASML"] },
    { "pattern": "ev|electric vehicle|battery|lithium", "weight": 0.6, "symbols": ["TSLA", "LI", "NIO", "RIVN", "ALB"] },
    { "pattern": "ai|artificial intelligence|llm|gpt|machine learning", "weight": 0.6, "symbols": ["NVDA", "MSFT", "GOOGL", "META", "AMD"] },
    { "pattern": "tariff|trade war|sanctions|export control", "weight": 0.6, "symbols": ["AAPL", "TSM", "NVDA", "QCOM", "AVGO"] }
  ]
}
```

### 3.3 与现有 `shared/stocks.json` 的关系

- `shared/stocks.json` 保持不变（仅用于行情面板的 symbol 列表）
- `shared/stock-watchlist.json` 是新文件，扩展了别名/行业/关键词维度
- `stocks.json` 中的 28 只股票会全部纳入 watchlist，再扩展到 ~200 只

### 3.4 初始化策略

加载 `stock-watchlist.json` 时，一次性完成：
1. 所有 aliases / keywords 做 `normalize()`、去重、按长度降序排列
2. 对 symbol 和 <=4 字符的别名，构建带单词边界的预编译正则
3. 对 `thematic_triggers` 中每个 pattern，预编译为 `RegExp(pattern, 'i')`
4. 结果缓存在模块级变量中，整个进程生命周期只编译一次

---

## 4. 核心算法

### 4.1 预处理

```typescript
const MAX_CONTENT_LEN = 20_000;

function preprocess(title: string, content?: string): string {
  const raw = content
    ? `${title} ${content.slice(0, MAX_CONTENT_LEN)}`  // 先裁剪再 normalize
    : title;
  return normalize(raw);  // lowercase + 全角→半角 + 去控制字符 + trim
}
```

### 4.2 Recall（候选生成）

三层匹配，按信号强度排序：

| 层级 | 匹配方式 | 信号强度 | 说明 |
|------|---------|---------|------|
| L1 | 别名精确匹配 | 1.0 | symbol/name/aliases 出现在 searchText 中 |
| L2 | 主题触发词匹配 | 配置权重 | thematic_triggers 预编译正则命中 |
| L3 | 关键词匹配（低权重） | 0.3 | stock.keywords 命中，弱信号 |

**短词边界匹配策略（`matchesTerm`）：**

```typescript
// 阈值 <= 4：META 也可能误命中 "metadata"/"meta-analysis"
const SHORT_TERM_THRESHOLD = 4;

function matchesTerm(searchText: string, term: string): boolean {
  const normalized = normalize(term);
  if (normalized.length <= SHORT_TERM_THRESHOLD) {
    // 短词：使用单词边界正则，避免 V/MA/AI/META 等误报
    // 对中文别名（非 ASCII），仍使用 includes
    if (/^[a-z0-9]+$/i.test(normalized)) {
      return new RegExp(`(?:^|[^a-zA-Z0-9])${escapeRegex(normalized)}(?:[^a-zA-Z0-9]|$)`, 'i').test(searchText);
    }
  }
  return searchText.includes(normalized);
}
```

> 注：中文别名（如 "苹果"、"英伟达"）无空格分词问题，`includes()` 是正确的匹配方式。

**匹配逻辑：**

```typescript
function recall(searchText: string, watchlist: CompiledWatchlist, maxCandidates: number): CandidateMatch[] {
  const candidates = new Map<string, CandidateMatch>();

  // L1: 别名精确匹配
  for (const stock of watchlist.stocks) {
    for (const term of stock.allTerms) {  // [symbol, name, ...aliases]，已预编译
      if (term.match(searchText)) {
        upsert(candidates, stock.symbol, {
          score: 1.0,
          evidence: { type: IMPACT_EVIDENCE_TYPE_ALIAS_MATCH, matchedTerm: term.raw, confidence: 1.0 }
        });
      }
    }
  }

  // L2: 主题触发词（预编译正则）
  for (const trigger of watchlist.compiledTriggers) {
    if (trigger.re.test(searchText)) {
      for (const symbol of trigger.symbols) {
        upsert(candidates, symbol, {
          score: trigger.weight,
          evidence: { type: IMPACT_EVIDENCE_TYPE_THEME_TRIGGER, matchedTerm: trigger.pattern, confidence: trigger.weight }
        });
      }
    }
  }

  // L3: 关键词匹配（低权重）
  for (const stock of watchlist.stocks) {
    for (const keyword of stock.normalizedKeywords) {
      if (searchText.includes(keyword)) {
        upsert(candidates, stock.symbol, {
          score: 0.3,
          evidence: { type: IMPACT_EVIDENCE_TYPE_KEYWORD_MATCH, matchedTerm: keyword, confidence: 0.3 }
        });
      }
    }
  }

  return [...candidates.values()]
    .sort((a, b) => b.score - a.score)
    .slice(0, maxCandidates);
}
```

**同一股票多次命中时，取最高分 + 合并所有 evidence。**

### 4.3 Precision（验证/排序）

对 Recall 输出的 topN（默认取前 15 个）做精排：

**Step 1：LLM 判断**（必须，单次批量调用）
- 输入：新闻标题/摘要 + 候选股票列表
- 输出：每只股票的 direction + reasons + score
- 使用现有 `callLlm()`，provider 链：ollama → groq → openrouter

**Step 2：Headlines 验证**（可选，当 `include_stock_news_headlines=true`）
- 对 topK 批量调用 `searchRecentStockHeadlines(symbol, name)`
- 并发控制：`HEADLINES_CONCURRENCY = 5`，分批 `Promise.allSettled`
- 从返回的 headlines 中检查是否提及相关实体（轻量字符串匹配）
- 结果作为 `IMPACT_EVIDENCE_TYPE_NEWS_HEADLINE` 类型的 evidence 附加

**Step 3：AnalyzeStock 验证**（可选，当 `include_analyze_stock=true`，默认关闭）
- 对 topK 调用 `analyzeStock(symbol, name, includeNews=true)`
- 并发控制：`ANALYZE_CONCURRENCY = 3`
- 注意：cache miss 时成本高（Yahoo History + LLM overlay），仅在热门股票缓存命中率高时有价值
- 结果嵌入 `ImpactedStock.analysis` 字段

**Step 4：最终排序**
```typescript
// 权重常量，集中定义便于调参
const WEIGHT_RECALL = 0.4;
const WEIGHT_LLM = 0.4;
const WEIGHT_SENSITIVITY = 0.2;

// 最低分阈值：低于此分的候选不返回（空结果策略）
const MIN_FINAL_SCORE = 0.15;

finalScore = WEIGHT_RECALL * recallScore + WEIGHT_LLM * llmScore + WEIGHT_SENSITIVITY * sensitivityScore;
// sensitivityScore：Phase 1 用固定启发式值（按行业分配）
```

**空结果保证**：LLM 返回 `relevant=false` 的候选，以及 `finalScore < MIN_FINAL_SCORE` 的候选，全部过滤。

### 4.4 LLM Prompt 设计

```typescript
const SYSTEM_PROMPT = `You are a financial analyst. Given a news headline and a list of candidate stocks, evaluate each stock's relevance to the news.

Return strict JSON only. Do not wrap in markdown fences or code blocks.
{
  "assessments": [
    {
      "symbol": "AAPL",
      "relevant": true,
      "direction": "bearish",
      "score": 0.85,
      "reasons": ["Supply chain disruption directly impacts iPhone production timeline"]
    }
  ]
}

Rules:
- Only mark a stock as relevant if the news has a clear, direct or indirect causal link
- Score 0-1 where 1 = highest confidence of impact
- direction: bullish/bearish/neutral
- reasons: array of concise sentences explaining the causal chain
- Be conservative: when in doubt, mark relevant=false
- Do NOT force-link generic macro news to specific large-cap stocks without a clear causal mechanism
- When multiple companies share a name or abbreviation, only mark the one with a clear industry match`;
```

**LLM validate 实现：**

```typescript
validate: (content) => {
  try {
    // 防御 markdown fences 包裹
    const jsonStr = content.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/i, '');
    const parsed = JSON.parse(jsonStr);
    return Array.isArray(parsed.assessments) && parsed.assessments.length > 0
      && parsed.assessments.every((a: any) => typeof a.symbol === 'string' && typeof a.relevant === 'boolean');
  } catch {
    return false;
  }
}
```

**成本控制**：
- 单次 LLM 调用处理所有候选（不是每个股票一次调用）
- maxTokens: 800（足够 15 个候选的评估）
- temperature: 0.1（需要确定性判断）
- LLM 失败时 throw（不 return null），确保 `cachedFetchJson` 不写入负缓存 sentinel

---

## 5. 文件变更清单

### 5.1 新增文件

| 文件 | 说明 |
|------|------|
| `proto/worldmonitor/market/v1/suggest_impacted_stocks.proto` | Proto 消息定义 |
| `shared/stock-watchlist.json` | Watchlist 词典（~200 只股票 + 别名 + 行业 + 主题触发词） |
| `server/worldmonitor/market/v1/suggest-impacted-stocks.ts` | RPC handler 主文件 |
| `server/worldmonitor/market/v1/stock-recall.ts` | Recall 引擎（词典加载/预编译 + 匹配逻辑） |

### 5.2 修改文件

| 文件 | 变更 |
|------|------|
| `proto/worldmonitor/market/v1/service.proto` | 新增 `import` + RPC 定义 |
| `server/worldmonitor/market/v1/handler.ts` | 新增 `suggestImpactedStocks` import 和注册 |
| `server/gateway.ts` | `RPC_CACHE_TIER` 新增条目 + `PREMIUM_RPC_PATHS` 新增 |
| `server/_shared/rate-limit.ts` | `ENDPOINT_RATE_POLICIES` 新增条目（120/60s） |

### 5.3 自动生成（`make generate` 后）

| 文件 | 说明 |
|------|------|
| `src/generated/server/worldmonitor/market/v1/service_server.ts` | 新增 handler 接口方法 + 路由 |
| `src/generated/client/worldmonitor/market/v1/service_client.ts` | 新增客户端方法 |
| `docs/api/worldmonitor/market/v1/service.openapi.yaml` | OpenAPI spec 新增 |

---

## 6. 缓存策略

### 6.1 Redis 缓存

```typescript
// cache key 覆盖所有影响响应形态的参数
function buildCacheKey(req: SuggestImpactedStocksRequest): string {
  const universe = req.universe || 'WATCHLIST';
  const lang = req.lang || 'en';
  const variant = req.variant || 'finance';
  const maxCandidates = req.maxCandidates || 30;
  const topK = req.topK || 10;
  const flags = [
    req.includeEvidence !== false ? 'e' : '',
    req.includeStockNewsHeadlines ? 'h' : '',
    req.includeAnalyzeStock ? 'a' : '',
  ].join('');
  const hash = stableHash(`${req.title}|${req.url || ''}|${req.content || ''}`);
  return `market:suggest-impact:v1:${universe}:${lang}:${variant}:${maxCandidates}:${topK}:${flags}:${hash}`;
}
```

> `stableHash` 使用与 `stock-news-search.ts` 相同的 FNV-1a 实现（需导出或复制）。

- TTL：统一 **6 小时**（新闻时效性平衡）
- 使用 `cachedFetchJson()` — 自动获得请求合并 + 负缓存
- **负缓存处理**：fetcher 中 LLM 失败/上游 429 时 **throw** 而非 return null，确保不写入负缓存 sentinel（`cachedFetchJson` 的 catch 路径不会写 sentinel）。仅当 Recall 无候选（真正无结果）时 return null。

### 6.2 CDN 缓存

- `RPC_CACHE_TIER` 设为 `slow`（30min `s-maxage`）
- POST 请求不会被 Vercel/CDN 缓存，此配置仅保持响应头一致性
- 实际缓存以 Redis 为主

---

## 7. 并发与成本控制

| 操作 | 每次请求最大调用次数 | 单次耗时预估 |
|------|---------------------|-------------|
| Recall（纯内存词典匹配） | 1 | < 5ms |
| LLM 精排（单次批量调用） | 1 | 2-5s |
| Headlines 验证（可选） | topK 个（并发 5） | 每个 0.5-2s（多数缓存命中） |
| AnalyzeStock 验证（可选，不推荐高频） | topK 个（并发 3） | 每个 3-8s（cache miss 时） |

**总延迟预估**：
- 基础模式（Recall + LLM）：**2-6 秒**
- 含 headlines 验证：**3-8 秒**
- 含 analyzeStock（不推荐高频）：**8-15 秒**
- Redis 命中时：**< 100ms**

---

## 8. 数据流图

```
                    ┌──────────────────────┐
                    │   HTTP POST Request  │
                    │  /suggest-impacted-  │
                    │       stocks         │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │   Redis Cache Check  │
                    │  cachedFetchJson()   │
                    └──────────┬───────────┘
                          miss │
                    ┌──────────▼───────────┐
                    │     Preprocess       │
                    │  slice + normalize   │
                    │  (title + content)   │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │   Recall Engine      │
                    │  stock-recall.ts     │
                    │                      │
                    │  L1: alias match     │
                    │  L2: theme trigger   │
                    │  L3: keyword match   │
                    └──────────┬───────────┘
                               │ candidates[]
                    ┌──────────▼───────────┐
                    │   LLM Precision      │
                    │  callLlm() 单次批量  │
                    │  → score + direction │
                    │  + reasons           │
                    │  (validate: strip    │
                    │   markdown fences)   │
                    └──────────┬───────────┘
                               │ ranked[]
                               │
              ┌────────────────┼────────────────┐
              │ opt            │ opt             │
     ┌────────▼────────┐  ┌───▼──────────┐      │
     │ headlines verify│  │ analyzeStock │      │
     │ searchRecent-   │  │ (不推荐高频) │      │
     │ StockHeadlines()│  │ 并发 max 3   │      │
     │ 并发 max 5      │  └───┬──────────┘      │
     └────────┬────────┘      │                 │
              └───────┬───────┘                 │
                      │                         │
              ┌───────▼──────────┐              │
              │  Filter & Sort   │              │
              │  finalScore <    │◄─────────────┘
              │  MIN_FINAL_SCORE │
              │  → drop          │
              └───────┬──────────┘
                      │
              ┌───────▼──────────┐
              │  Build Response  │
              │  + cache Redis   │
              └───────┬──────────┘
                      │
              ┌───────▼──────────┐
              │ SuggestImpacted- │
              │ StocksResponse   │
              └──────────────────┘
```

---

## 9. Phase 2 扩展点（路线 B）

Phase 1 落地后，路线 B 增强只需在 Recall 层插入新来源，Precision 层不变：

| 扩展 | 实现方式 | 依赖 |
|------|---------|------|
| Finnhub symbol search | 从新闻中提取公司名 → `GET /search?q={name}` → 返回匹配 tickers | `FINNHUB_API_KEY` |
| LLM 实体提取 | `callLlm()` 从新闻中提取公司/品牌/供应链实体名（**只输出公司名，不直接出 ticker**，降低幻觉） | 现有 LLM 链 |
| 搜索 provider 验证 | 对 LLM 提取的公司名，用 Tavily/Brave 搜索 `"{company} stock ticker"` 确认 | `TAVILY_API_KEYS` 等 |
| Embedding 相似度 | 新闻 embedding vs watchlist 股票描述 embedding（弱信号，作为 L4 层） | 本地 embedding 或 API |

扩展时 `stock-recall.ts` 的接口保持不变（返回 `CandidateMatch[]`），只需添加新的 recall source。

**全市场召回约束**：必须有候选上限（`maxCandidates`）+ 每个候选必须有可解释 evidence，否则输出噪声不可控。

---

## 10. 验收标准

### Phase 1 功能验收

**公司直接相关新闻**（recall@5 目标 > 90%）：

| 场景 | 预期结果 |
|------|---------|
| "Apple reports record iPhone sales in China" | top1 命中 AAPL |
| "TSMC plans new Arizona fab" | top1 命中 TSM，候选含半导体板块 |
| "NVIDIA unveils next-gen Blackwell GPU" | top1 命中 NVDA |

**宏观/主题新闻**（recall@10 目标 > 60%）：

| 场景 | 预期结果 |
|------|---------|
| "OPEC announces production cut" | 返回能源股候选（XOM, CVX 等） |
| "Fed raises interest rates by 25 basis points" | 返回银行股候选（JPM, BAC 等） |
| "US imposes new semiconductor export controls" | 返回半导体/关税相关候选 |

**负面测试集（短 ticker 误报验证）**：

| 场景 | 预期结果 |
|------|---------|
| "The MA program at Harvard is highly competitive" | **不**命中 MA（Mastercard） |
| "V formation spotted in chart analysis" | **不**命中 V（Visa） |
| "Meta-analysis of recent clinical trials" | **不**命中 META（Meta Platforms） |
| "AI technology transforms healthcare industry" | 命中 AI 主题触发词，但**不**因字母 "AI" 误命中无关股票 |
| "Local sports team wins championship" | 返回空列表 |

### 性能指标

| 指标 | 目标值 |
|------|--------|
| P95 延迟（基础模式） | < 6s |
| P95 延迟（含 headlines） | < 10s |
| Redis 命中延迟 | < 200ms |
| 每条新闻 LLM 调用次数 | 1 |
| 公司相关新闻 recall@5 | > 90% |
| 宏观新闻 recall@10 | > 60% |
| 短 ticker 误报率 | < 5% |

---

## 11. 实施节奏

| 阶段 | 内容 | 预估耗时 |
|------|------|---------|
| Step 1 | Proto 定义 + `make generate` | 0.5h |
| Step 2 | `stock-watchlist.json` 初版（50 只核心股票 + 别名 + 6 个主题触发组） | 2h |
| Step 3 | `stock-recall.ts`（词典加载/预编译 + 匹配引擎 + matchesTerm 边界策略） | 2h |
| Step 4 | `suggest-impacted-stocks.ts`（handler + LLM 精排 + validate + 缓存） | 3h |
| Step 5 | `handler.ts` 注册 + `gateway.ts` 缓存/premium + `rate-limit.ts` 限流 | 0.5h |
| Step 6 | 缓存 key/参数一致性测试 | 0.5h |
| Step 7 | 用 50 条标注新闻做冒烟测试（含短 ticker 负面集），调优 thematic_triggers | 2h |
| **合计** | | **~10.5h / 1.5 天** |

---

## 附录：Review 意见处理记录

| # | 意见 | 处理 | 理由 |
|---|------|------|------|
| 1 | 纳入 Premium | 采纳 | 现有 LLM 类 RPC 均在 PREMIUM_RPC_PATHS |
| 2 | 去掉 analyzeStock fan-out | 部分采纳 | 保留为可选（默认关闭）；有 15min 缓存，热门股命中率高时成本可接受 |
| 3 | 空结果策略 | 采纳 | 增加 MIN_FINAL_SCORE 阈值过滤 |
| 4 | POST 不混用 query 注解 | 采纳 | 仓库 3 个 POST RPC 均无 query 注解 |
| 5 | 字段 validate 边界 | 部分采纳 | title 加 max_len；content 在 handler 层裁剪（不在 proto 限制） |
| 6 | AnalyzeStockResponse 轻量化 | 暂不采纳 | 字段 optional 且默认关闭，过早抽象 |
| 7 | CDN 不缓存 POST | 采纳 | 以 Redis 为主缓存 |
| 8 | thematic_triggers 改数组 | 采纳 | 加载时预编译 + 带权重 |
| 9 | 短 ticker 边界匹配 | 采纳 | V/MA/PG/HD 等必须单词边界匹配，阈值设为 <=4（含 META） |
| 10 | L3 命名 | 采纳 | 改为"keyword match（低权重）" |
| 11 | 预编译优化 | 采纳 | 模块级一次性编译 |
| 12 | 先裁剪再 normalize | 采纳 | 防恶意超长 content |
| 13 | token 边界辅助 | 不采纳 | 对中文别名不适用；英文短词用 \b 正则已够 |
| 14 | matchesTerm 策略 | 采纳 | 阈值调整为 <=4（含 META） |
| 15 | 预编译 regex | 采纳 | |
| 16 | LLM validate 防 markdown | 采纳 | 低成本防御性编程 |
| 17 | LLM validate 检查结构 | 采纳 | 检查 assessments 数组 + symbol + relevant 字段 |
| 18 | 验证降级为 headlines | 部分采纳 | headlines 作为默认轻量选项；analyzeStock 保留但标注不推荐 |
| 19 | finalScore 权重定义为常量 | 采纳 | 便于调参 |
| 20 | reasons 统一为数组 | 采纳 | prompt 与 proto 一致 |
| 21 | 同名歧义约束 | 采纳 | prompt 增加约束 |
| 22 | 端点限流 | 采纳 | 120/60s |
| 23 | premium 强制 key | 采纳 | 同意见 1 |
| 24 | TTL 关键词可配置 | 不采纳 | 过度设计；Phase 1 统一 6h TTL |
| 25 | 负缓存区分 | 采纳 | 通过 fetcher 正确 throw/return null 控制（现有机制已支持） |
| 26 | 移除 analyzeStock 档 | 不采纳 | 保留可选，标注不推荐 |
| 27 | 响应返回 provider/model | 采纳 | 新增 llm_provider/llm_model/llm_fallback 字段 |
| 28 | 短 ticker 误报测试 | 采纳 | 增加负面测试集 |
| 29 | 验收分类 | 采纳 | 公司相关 recall@5 > 90%，宏观 recall@10 > 60% |
| 30 | 增加 premium/rate limit step | 采纳 | Step 5 合并 |
| 31 | 缓存一致性测试 | 采纳 | 新增 Step 6 |
