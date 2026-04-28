# 阿里云 ACR 自动构建与推送

## 目标镜像

- Registry: `registry.cn-beijing.aliyuncs.com`
- Namespace: `xiaozhu245`
- Image: `ubuntu_ssh`
- 完整镜像名: `registry.cn-beijing.aliyuncs.com/xiaozhu245/ubuntu_ssh`

## 已添加的 CI/CD 文件

- 工作流: `.github/workflows/acr-publish.yml`
- 构建上下文忽略: `.dockerignore`

## 触发规则

- 仅支持在 GitHub Actions 页面手动触发

## 推送的镜像标签

- 默认分支推送时附带 `latest`
- 分支推送时附带分支名标签
- Git 标签推送时附带对应版本标签
- 每次构建都会附带 `sha-<commit>` 标签

## 需要配置的 GitHub Secrets

在仓库的 `Settings -> Secrets and variables -> Actions` 中新增：

- `ALIYUN_REGISTRY_USERNAME`
  - 值填写阿里云镜像仓库登录用户名，例如 `yxsj2459561`
- `ALIYUN_REGISTRY_PASSWORD`
  - 值填写阿里云 ACR 访问凭证密码

## 使用方式

### 1. 手动执行发布

进入仓库的 `Actions` 页面，选择 `Build and Push Docker Image` 工作流后点击 `Run workflow`。

执行后会推送类似以下标签：

```bash
registry.cn-beijing.aliyuncs.com/xiaozhu245/ubuntu_ssh:latest
registry.cn-beijing.aliyuncs.com/xiaozhu245/ubuntu_ssh:main
registry.cn-beijing.aliyuncs.com/xiaozhu245/ubuntu_ssh:sha-<commit>
```

### 2. 手动执行并使用标签

如果需要版本标签，建议先在代码仓库中创建对应 Git 标签，再手动执行工作流。

例如创建 `v1.0.0` 标签后，镜像可使用：

```bash
registry.cn-beijing.aliyuncs.com/xiaozhu245/ubuntu_ssh:v1.0.0
registry.cn-beijing.aliyuncs.com/xiaozhu245/ubuntu_ssh:sha-<commit>
```

## 手动拉取镜像

```bash
docker login --username=yxsj2459561 registry.cn-beijing.aliyuncs.com
docker pull registry.cn-beijing.aliyuncs.com/xiaozhu245/ubuntu_ssh:latest
```

## 本地手动推送示例

如果需要在本地手动推送，可执行：

```bash
docker login --username=yxsj2459561 registry.cn-beijing.aliyuncs.com
docker build -t ubuntu_ssh:local .
docker tag ubuntu_ssh:local registry.cn-beijing.aliyuncs.com/xiaozhu245/ubuntu_ssh:local
docker push registry.cn-beijing.aliyuncs.com/xiaozhu245/ubuntu_ssh:local
```

## 可选调整

如果后续需要修改仓库地址，只需要更新工作流中的这几个环境变量：

- `REGISTRY`
- `NAMESPACE`
- `IMAGE_NAME`

## 说明

- 当前工作流默认使用公网地址 `registry.cn-beijing.aliyuncs.com`
- GitHub Actions 运行器通常不在阿里云 VPC 内，因此不建议在该工作流中改为 `registry-vpc.cn-beijing.aliyuncs.com`
- 如果后续改用阿里云 ECS 自建 Runner，并且机器位于 VPC 网络，再考虑切换为 VPC 地址
