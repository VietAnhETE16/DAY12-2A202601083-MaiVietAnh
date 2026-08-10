# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Mai Việt Anh  Mã học viên: 2A202601083

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống: Khi deploy service lên production (Render/Railway), dev quên thêm biến môi trường `AGENT_API_KEY` vào dashboard.
> - Nếu có mặc định là `"changeme"`, app vẫn khởi động bình thường. Kẻ xấu có thể đoán được key mặc định `"changeme"` và gọi API thoải mái, làm cạn kiệt ngân sách hoặc lộ tài nguyên LLM mà dev không hề hay biết cho đến khi nhận hóa đơn.
> - Việc "chết sớm" (fail fast): App sẽ văng lỗi `ValidationError` ngay lúc khởi động, quá trình deploy báo đỏ lập tức. Dev phát hiện và bổ sung biến môi trường ngay trước khi mở traffic cho người dùng.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log JSON thu được:
> `{"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T02:50:00.000000+00:00", "user_id": "sv01", "tokens_in": 12, "tokens_out": 25, "cost_usd": 0.00015}`
>
> Hai việc làm được với log JSON mà `print()` không làm được:
> 1. **Lọc, truy vấn và thống kê tự động qua Log Aggregator (Datadog, Loki, CloudWatch):** Hệ thống có thể parse trường JSON để tính tổng `cost_usd` theo từng `user_id` hoặc tính trung bình token sử dụng trong ngày.
> 2. **Tạo cảnh báo (Alerting) tự động:** Có thể đặt rule tự động kích hoạt cảnh báo nếu `cost_usd` vượt ngưỡng hoặc `level == "error"` tăng đột biến.


---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1050 MB |
| Multi-stage | ~482 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Phần dung lượng chênh lệch (~568 MB) gồm:
> 1. **Base image & Build tools:** Bản gốc dùng `python:3.11` chứa đầy đủ bộ công cụ biên dịch (`gcc`, `g++`, `make`, build headers, thư viện hệ thống thừa), trong khi `python:3.11-slim` đã loại bỏ các package này.
> 2. **Rác phát sinh khi build:** Trong multi-stage build, toàn bộ cache tải về của pip, file tạm thời khi compile dependencies chỉ nằm lại ở stage `builder` và bị huỷ bỏ, stage `runtime` chỉ copy phần kết quả cài đặt sạch sang `/usr/local`.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> - **Với Dockerfile hiện tại:** Các layer `COPY requirements.txt .`, `RUN pip install ...`, `COPY --from=builder /install /usr/local`, và `RUN useradd ...` đều được **dùng lại từ cache** (vì `requirements.txt` không đổi). Chỉ layer `COPY app ./app` và các bước sau đó (`chown`, `HEALTHCHECK`, `CMD`) mới phải chạy lại.
> - **Nếu đặt `COPY . .` trước `RUN pip install`:** Mỗi khi sửa 1 dòng code trong `app/main.py`, cache của layer `COPY . .` bị mất hiệu lực, kéo theo lệnh `RUN pip install` phải tải và cài lại toàn bộ thư viện từ đầu, làm tăng thời gian build từ vài giây lên vài phút.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> - **Chuỗi sự kiện:**
>   1. Code Python có lỗ hổng (ví dụ Command Injection, Remote Code Execution qua thư viện bên thứ 3).
>   2. Kẻ tấn công gửi payload khai thác thành công và thực thi shell/code độc hại. Do container chạy dưới quyền `root` (UID 0), kẻ tấn công sở hữu toàn quyền root trong container.
>   3. Từ quyền root trong container, kẻ tấn công tận dụng các lỗ hổng nhân Linux / Container Escape (hoặc quyền ghi vào mounted socket/volumes) để thoát khỏi container và chiếm quyền `root` trên chính máy host.
> - **Lệnh `USER` cắt đứt ở chỗ:** Lệnh `USER appuser` ép tiến trình chạy với user thường (UID 10001, không có quyền sudo). Khi bị khai thác mã độc, kẻ tấn công chỉ có quyền hạn tối thiểu, không thể sửa file hệ thống trong container và không có quyền root capabilities để thực hiện container escape lên máy host.


---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> *Câu trả lời của bạn*

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> *Câu trả lời của bạn*

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> *Câu trả lời của bạn*

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> *Câu trả lời của bạn*

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> *Câu trả lời của bạn*
