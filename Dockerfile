# 第一阶段：编译 Go 程序
FROM golang:1.16-buster AS builder

WORKDIR /src
COPY . .

RUN go env -w GO111MODULE=auto

# 增加 CGO_ENABLED=0 和 GOOS=linux
# "dhi.io/static:20250419"是精简的静态运行环境，不适合依赖额外动态链接库的程序。
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# 第二阶段：运行 Go 程序
FROM dhi.io/static:20250419

WORKDIR /

COPY --from=builder /src/main /main

EXPOSE 3000

ENTRYPOINT ["/main"]
