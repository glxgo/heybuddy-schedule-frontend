# 相伴课表 — 自定义 API 服务 Dockerfile（通用模板）
# 基于 Node.js，不含任何业务特定依赖或第三方 SDK。

FROM node:20-bookworm-slim

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY . ./

EXPOSE 3000

CMD ["node", "index.js"]
