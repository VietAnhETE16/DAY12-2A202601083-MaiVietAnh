# ═══════════════════════════════════════════════════════════════════
# CP2 — Production-ready Multi-stage Dockerfile
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Builder — Cài đặt dependencies vào prefix riêng
FROM python:3.11-slim AS builder

WORKDIR /app

# Copy riêng requirements.txt và cài đặt để tận dụng Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime — Image cuối cùng nhẹ và bảo mật
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy các package đã build từ builder stage sang
COPY --from=builder /install /usr/local

# Tạo non-root user để chạy ứng dụng (bảo mật)
RUN useradd --create-home --uid 10001 appuser

# Copy mã nguồn ứng dụng
COPY app ./app
COPY utils ./utils

# Phân quyền cho appuser và chuyển sang user đó
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Healthcheck thăm dò trạng thái qua /health
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:' + str(__import__('os').getenv('PORT', 8000)) + '/health').read()" || exit 1

CMD ["python", "-m", "app.main"]
