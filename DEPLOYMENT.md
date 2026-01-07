# 部署到 GitHub Pages 指南

## 📋 前置条件

- [x] GitHub 账号
- [x] 仓库名称：`leokang28/leokang28.github.io`
- [x] 本地项目已完成配置

## 🚀 部署步骤

### 步骤 1: 初始化 Git 仓库（如果还没有）

```bash
cd /d/a_site
git init
git add .
git commit -m "Initial commit: Zola blog setup"
```

### 步骤 2: 连接到 GitHub 仓库

```bash
# 添加远程仓库
git remote add origin https://github.com/leokang28/leokang28.github.io.git

# 或者使用 SSH
git remote add origin git@github.com:leokang28/leokang28.github.io.git

# 推送到 main 分支
git branch -M main
git push -u origin main
```

### 步骤 3: 配置 GitHub Pages

1. 访问：https://github.com/leokang28/leokang28.github.io/settings/pages
2. 在 **Build and deployment** 部分：
   - **Source**: 选择 `GitHub Actions`
   - ⚠️ **不要**选择 "Deploy from a branch"

![GitHub Pages Settings](https://docs.github.com/assets/cb-143188/mw-1440/images/help/pages/publishing-source-drop-down.webp)

### 步骤 4: 查看部署状态

1. 访问：https://github.com/leokang28/leokang28.github.io/actions
2. 等待工作流完成（通常 2-5 分钟）
3. 绿色勾号 ✅ = 部署成功
4. 红色叉号 ❌ = 部署失败（点击查看日志）

### 步骤 5: 访问网站

部署成功后，访问：**https://leokang28.github.io**

## 📁 项目结构

```
a_site/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions 工作流
├── content/                     # 文章内容
│   ├── blog/                   # 博客文章
│   └── archive/                # 归档页面
├── templates/                   # 自定义模板
│   ├── base.html               # 基础模板
│   └── archive.html            # 归档模板
├── static/                      # 静态资源
│   ├── css/
│   │   └── custom.css          # 自定义样式
│   └── favicon.ico             # 网站图标
├── themes/                      # 主题
│   └── anemone/                # 当前使用的主题
├── config.toml                  # Zola 配置
└── .gitignore                   # Git 忽略文件
```

## 🔄 日常更新流程

### 发布新文章

```bash
# 1. 在 content/blog/ 创建新文章
vim content/blog/new-post.md

# 2. 本地预览
zola serve

# 3. 提交并推送
git add content/blog/new-post.md
git commit -m "Add new post: Title"
git push

# 4. GitHub Actions 自动部署（2-5 分钟）
```

### 修改配置或样式

```bash
# 1. 修改文件
vim config.toml
# 或
vim static/css/custom.css

# 2. 本地测试
zola serve

# 3. 提交推送
git add .
git commit -m "Update site configuration"
git push
```

## 🐛 故障排查

### 问题 1: Actions 工作流失败

**查看日志**：

1. 访问 Actions 标签
2. 点击失败的工作流
3. 查看详细错误信息

**常见原因**：

- Zola 版本不兼容
- 主题 submodule 未正确配置
- config.toml 语法错误

**解决方法**：

```bash
# 本地测试构建
zola build

# 如果本地成功，检查 submodule
git submodule update --init --recursive
```

### 问题 2: 页面 404

**检查清单**：

- [ ] GitHub Pages 设置为 "GitHub Actions"
- [ ] 工作流已成功运行
- [ ] base_url 配置正确
- [ ] 等待 5-10 分钟（DNS 传播）

### 问题 3: 样式丢失

**检查**：

- `config.toml` 中的 `base_url` 是否正确
- 静态资源是否正确提交到 Git

### 问题 4: 主题文件丢失

**如果主题是 submodule**：

```bash
# 添加主题 submodule
git submodule add https://github.com/Speyll/anemone.git themes/anemone

# 提交
git add .gitmodules themes/
git commit -m "Add theme as submodule"
git push
```

**如果主题直接复制**：

```bash
# 确保主题文件已提交
git add themes/anemone
git commit -m "Add theme files"
git push
```

## 🔐 使用自定义域名（可选）

### 步骤 1: 添加 CNAME 文件

```bash
echo "yourdomain.com" > static/CNAME
git add static/CNAME
git commit -m "Add custom domain"
git push
```

### 步骤 2: 配置 DNS

在你的域名提供商添加记录：

```
Type: CNAME
Name: www (或 @)
Value: leokang28.github.io
```

### 步骤 3: 更新 config.toml

```toml
base_url = "https://yourdomain.com"
```

## 📊 监控部署

### 查看构建时间

```bash
# 在 Actions 页面可以看到：
- 构建时间：通常 1-2 分钟
- 部署时间：通常 30 秒
- 总时间：2-3 分钟
```

### 设置通知

1. 访问：Settings → Notifications
2. 启用 Actions 通知
3. 选择接收方式（Email/Web）

## 🎉 完成

现在你的博客已经：

- ✅ 自动构建
- ✅ 自动部署
- ✅ 可公开访问
- ✅ 支持 HTTPS

每次推送到 `main` 分支，网站都会自动更新！

## 🔗 有用的链接

- [Zola 文档](https://www.getzola.org/documentation/)
- [GitHub Pages 文档](https://docs.github.com/en/pages)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Anemone 主题](https://github.com/Speyll/anemone)
