# DB Term Project — Instagram 스타일 사진 공유 서비스

MySQL + Python(FastAPI, Jinja2) + mysql-connector-python

## 구현 기능

| 요구사항 | 경로 |
|---|---|
| 회원가입 / 로그인 / 로그아웃 | `/signup`, `/login`, `/logout` |
| 비밀번호 변경 | `/settings/password` |
| 팔로우·언팔로우 (승인 없음) | 프로필의 팔로우 버튼 |
| 팔로워·팔로잉 목록 | `/u/{id}/followers`, `/u/{id}/following` |
| 사진 + 캡션 업로드 | `/create` |
| 댓글, `@ID` 멘션 (존재하는 사용자면 프로필 링크) | 게시물 상세 `/p/{post_id}`, 피드 |
| 홈 피드 (내 글 + 팔로우한 사람 글, 최신순) | `/` |
| 아무 사용자 프로필 보기 (사진 그리드) | `/u/{id}` |
| (추가) 사용자 검색 | `/search` |

비밀번호는 평문이 아니라 PBKDF2-SHA256 해시로 `password_hash`에 저장한다.
이미지 파일은 `static/uploads/`에 저장하고 DB에는 경로만 둔다.

## 폴더 구조

```
app.py               라우트(페이지)와 SQL
db.py                MySQL 연결 (환경변수로 설정)
sql/schema.sql       테이블 생성 DDL
sql/sample_data.sql  예시 데이터 (모든 계정 비밀번호 1234)
sql/queries.sql      앱에서 쓰는 SQL 모음
templates/           Jinja2 HTML 템플릿
static/              CSS, 예시 사진, 업로드 폴더
```

## 실행 방법

1. MySQL 8.0을 설치하고 스키마와 예시 데이터를 넣는다.

   ```bash
   mysql -u root -p < sql/schema.sql
   mysql -u root -p --default-character-set=utf8mb4 < sql/sample_data.sql
   ```

2. 파이썬 패키지를 설치한다.

   ```bash
   python -m venv .venv
   source .venv/bin/activate        # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. DB 접속 정보를 환경변수로 주고 서버를 띄운다.

   ```bash
   # macOS / Linux
   export DB_USER=root DB_PASSWORD=비밀번호
   uvicorn app:app --reload
   ```

   ```powershell
   # Windows PowerShell
   $env:DB_USER="root"; $env:DB_PASSWORD="비밀번호"
   uvicorn app:app --reload
   ```

4. http://127.0.0.1:8000 접속 → `alice` / `1234`로 로그인.

| 환경변수 | 기본값 |
|---|---|
| `DB_HOST` | `localhost` |
| `DB_PORT` | `3306` |
| `DB_USER` | `root` |
| `DB_PASSWORD` | (빈 값) |
| `DB_NAME` | `instagram` |
| `SECRET_KEY` | 세션 서명 키 (배포 시 꼭 바꿀 것) |
