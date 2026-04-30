FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY server.js ./
COPY public ./public

EXPOSE 3000

ENV TARGET_DIR=/data
ENV PORT=3000

CMD ["node", "server.js"]
