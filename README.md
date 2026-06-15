# 株式会社UNOMI — 网站源码（Eleventy / 11ty）

这是把原本「13 个各自独立、互相复制的产物 HTML」重构成的**可维护源码工程**。
现在：共享的 header/footer/dock 只有一份、内容可数据化、样式有可读源文件，`npm run build` 一键产出与原站一致的静态页面。

> 核心原则：页面正文（`<main>`）逐字保留，外观与原站一致（已用 byte-diff 验证）。重构只动「共享外壳」与「构建方式」。

## 快速开始

```bash
npm install      # 安装 Eleventy
npm run dev      # 本地预览（带热更新）http://localhost:8080
npm run build    # 产出静态站点到 _site/，可直接部署
```

## 目录结构

```
unomi-11ty/
├─ .eleventy.js            # 构建配置（输入 src/，输出 _site/，静态资源直通）
├─ package.json
├─ src/
│  ├─ _includes/
│  │  ├─ base.njk          # ★ 全站母版：<head>、<body>、引用三个共享块
│  │  ├─ footer.njk        # ★ 页脚 + 导航（改这一处，全站生效）
│  │  ├─ dock.njk          # ★ 底部 UNOMI|CONTACT 胶囊按钮（单一来源）
│  │  ├─ scripts.njk       # ★ 全站底部脚本（WebGL、表单、统计等）
│  │  └─ seo/*.json        # 每页的 JSON-LD 结构化数据
│  ├─ _data/
│  │  └─ site.json         # 站点级变量（站名、域名）
│  ├─ assets/
│  │  └─ custom.css        # ★ 可读的自定义样式（dock、毛玻璃卡片）
│  ├─ index.njk            # 各页面：仅含「页面元信息 + <main> 正文」
│  ├─ about.njk
│  ├─ service.njk … 等
│  └─ topics-*.njk         # 3 篇专栏文章
└─ static/                 # 原样直通的资源：主题 CSS/JS、图片、字体、form 页等
```

## 常见改动怎么做（这就是重构的意义）

- **改底部按钮 / 页脚 / 导航**：只改 `src/_includes/dock.njk` 或 `footer.njk` **一个文件**，全站 13 页自动更新。（以前要改 7+ 个文件。）
- **改样式**：编辑 `src/assets/custom.css`（可读、带注释），不再往每页 `<style>` 里堆 `!important`。
- **改某页正文**：编辑对应的 `src/<page>.njk` 里 `{% raw %}...{% endraw %}` 之间的 `<main>`。
- **改页面标题/描述/分享图（SEO）**：改该页 `.njk` 顶部 front-matter 的 `title` / `description` / `ogImage`。
- **新增一个页面**：在 `src/` 加一个 `.njk`，写上 `layout: base.njk` 和 `permalink`，即自动套用全站外壳。

## 说明

- `static/` 里的主题 CSS（`style.css`）和 JS（`vendor.js` 等）仍是原始压缩产物（无源码），原样直通。若日后要彻底可改，需要拿到主题的 SCSS/JS 源码再接入构建——这是下一阶段。
- `form/`、`company/service/` 等特殊页未模板化，作为静态文件直通。
- 已统一所有共享资源为**根相对路径**（`/wp2025/...`），修复了原站各页 CSS 引用不一致甚至损坏（如 about 页原本的 `index.htmlwp2025/...`）的问题。
- 所有页面 URL 与原站完全一致，站内链接无需改动。

## 部署

把 `_site/` 整个目录部署到任意静态托管（Vercel / Netlify / Nginx）即可。Vercel 可直接设 build command 为 `npm run build`、output 为 `_site`。
