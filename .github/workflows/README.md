# GitHub Actions 自动部署

## 配置步骤

### 1. 确认仓库设置

确保你的仓库是 `leokang28/leokang28.github.io`

### 2. 配置 GitHub Pages

1. 进入仓库 Settings
2. 左侧菜单选择 **Pages**
3. 在 **Build and deployment** 部分：
   - Source: 选择 **GitHub Actions**
   - （不要选择 Deploy from a branch）

### 3. 推送代码

```bash
git add .
git commit -m "Add GitHub Actions workflow"
git push origin main
```

### 4. 查看部署状态

1. 进入仓库的 **Actions** 标签
2. 查看最新的工作流运行状态
3. 部署成功后，访问 https://leokang28.github.io

## 工作流说明

- **触发条件**:

  - 推送到 `main` 分支
  - 手动触发（Actions 页面）

- **构建步骤**:

  1. 检出代码（包括 submodules）
  2. 安装 Zola 0.19.2
  3. 运行 `zola build`
  4. 上传构建产物

- **部署步骤**:
  1. 将构建产物部署到 GitHub Pages

## 注意事项

1. 确保 `config.toml` 中的 `base_url` 正确：

   ```toml
   base_url = "https://leokang28.github.io"
   ```

2. 如果主题是 git submodule，确保已正确添加：

   ```bash
   git submodule add https://github.com/Speyll/anemone.git themes/anemone
   git submodule update --init --recursive
   ```

3. 首次部署可能需要 5-10 分钟

## 手动触发部署

1. 进入仓库的 **Actions** 标签
2. 选择 "Deploy to GitHub Pages" 工作流
3. 点击 **Run workflow** 按钮
4. 选择 `main` 分支
5. 点击 **Run workflow** 确认

## 故障排查

### 构建失败

- 检查 Actions 日志
- 确认 Zola 版本兼容性
- 确认所有依赖文件都已提交

### 部署失败

- 确认 GitHub Pages 设置为 "GitHub Actions"
- 检查仓库权限设置
- 查看 Actions 日志详细错误信息

### 页面无法访问

- 等待 5-10 分钟（DNS 传播）
- 检查 `config.toml` 中的 `base_url`
- 清除浏览器缓存
