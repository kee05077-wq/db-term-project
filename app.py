import hashlib
import hmac
import os
import re
import secrets
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, File, Form, Request, UploadFile
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from markupsafe import Markup, escape
from mysql.connector import IntegrityError
from starlette.middleware.sessions import SessionMiddleware

from db import execute, query

BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / "static" / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_UPLOAD = 10 * 1024 * 1024
USER_ID_RE = re.compile(r"^[A-Za-z0-9_.]{1,30}$")
MENTION_RE = re.compile(r"@([A-Za-z0-9_.]{1,30})")

app = FastAPI()
app.add_middleware(SessionMiddleware, secret_key=os.getenv("SECRET_KEY", "dev-secret-change-me"))
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")
templates = Jinja2Templates(directory=BASE_DIR / "templates")


# ---------------------------------------------------------------- helpers

def hash_password(password):
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 200_000).hex()
    return f"pbkdf2_sha256$200000${salt}${digest}"


def check_password(password, stored):
    try:
        _, iterations, salt, digest = stored.split("$")
    except ValueError:
        return False
    candidate = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), int(iterations)).hex()
    return hmac.compare_digest(candidate, digest)


class LoginRequired(Exception):
    pass


@app.exception_handler(LoginRequired)
def login_required_handler(request, exc):
    return RedirectResponse("/login", status_code=303)


def require_login(request):
    user_id = request.session.get("user_id")
    if not user_id:
        raise LoginRequired()
    return user_id


def render(request, name, **context):
    context.setdefault("me", request.session.get("user_id"))
    context.setdefault("flash", request.session.pop("flash", None))
    return templates.TemplateResponse(request, name, context)


def existing_mentions(texts):
    """Return the set of @IDs in the texts that are real users."""
    ids = {m for t in texts if t for m in MENTION_RE.findall(t)}
    if not ids:
        return set()
    marks = ",".join(["%s"] * len(ids))
    rows = query(f"SELECT user_id FROM `User` WHERE user_id IN ({marks})", tuple(ids))
    return {r["user_id"] for r in rows}


def link_mentions(text, valid):
    """Escape text and turn @ID of existing users into profile links."""
    def repl(m):
        uid = m.group(1)
        if uid in valid:
            return f'<a class="mention" href="/u/{uid}">@{uid}</a>'
        return m.group(0)
    return Markup(MENTION_RE.sub(repl, str(escape(text or ""))))


def time_ago(value):
    seconds = int((datetime.now() - value).total_seconds())
    if seconds < 60:
        return "방금 전"
    if seconds < 3600:
        return f"{seconds // 60}분 전"
    if seconds < 86400:
        return f"{seconds // 3600}시간 전"
    if seconds < 86400 * 7:
        return f"{seconds // 86400}일 전"
    return f"{value.year}년 {value.month}월 {value.day}일"


AVATAR_COLORS = ["#f58529", "#dd2a7b", "#8134af", "#515bd4", "#feda77", "#2a9d8f", "#e76f51", "#457b9d"]


def avatar_color(user_id):
    return AVATAR_COLORS[int(hashlib.md5(user_id.encode()).hexdigest(), 16) % len(AVATAR_COLORS)]


templates.env.filters["time_ago"] = time_ago
templates.env.filters["avatar_color"] = avatar_color
templates.env.globals["link_mentions"] = link_mentions


def avatar(user_id, size=32):
    """Schema has no profile image, so draw a colored circle with the initial."""
    style = f"width:{size}px;height:{size}px;font-size:{int(size * 0.42)}px;background:{avatar_color(user_id)}"
    return Markup(f'<span class="avatar" style="{style}">{escape(user_id[0].upper())}</span>')


templates.env.globals["avatar"] = avatar


def comments_by_post(post_ids):
    if not post_ids:
        return {}
    marks = ",".join(["%s"] * len(post_ids))
    rows = query(
        f"""SELECT comment_id, post_id, author_id, text, created_at
            FROM Comment WHERE post_id IN ({marks})
            ORDER BY created_at, comment_id""",
        tuple(post_ids),
    )
    grouped = {pid: [] for pid in post_ids}
    for r in rows:
        grouped[r["post_id"]].append(r)
    return grouped


# ---------------------------------------------------------------- auth

@app.get("/login")
def login_page(request: Request):
    if request.session.get("user_id"):
        return RedirectResponse("/", status_code=303)
    return render(request, "login.html")


@app.post("/login")
def login(request: Request, user_id: str = Form(...), password: str = Form(...)):
    user = query("SELECT user_id, password_hash FROM `User` WHERE user_id = %s", (user_id,), one=True)
    if not user or not check_password(password, user["password_hash"]):
        return render(request, "login.html", error="아이디 또는 비밀번호가 올바르지 않습니다.", user_id=user_id)
    request.session["user_id"] = user["user_id"]
    return RedirectResponse("/", status_code=303)


@app.get("/signup")
def signup_page(request: Request):
    return render(request, "signup.html")


@app.post("/signup")
def signup(request: Request, user_id: str = Form(...), display_name: str = Form(...),
           password: str = Form(...)):
    user_id, display_name = user_id.strip(), display_name.strip()
    form = {"user_id": user_id, "display_name": display_name}
    if not USER_ID_RE.match(user_id):
        return render(request, "signup.html", error="아이디는 영문, 숫자, _, . 만 사용해 30자 이내로 입력하세요.", **form)
    if not 1 <= len(display_name) <= 50:
        return render(request, "signup.html", error="이름은 1~50자로 입력하세요.", **form)
    if len(password) < 4:
        return render(request, "signup.html", error="비밀번호는 4자 이상이어야 합니다.", **form)
    try:
        execute("INSERT INTO `User` (user_id, password_hash, display_name) VALUES (%s, %s, %s)",
                (user_id, hash_password(password), display_name))
    except IntegrityError:
        return render(request, "signup.html", error="이미 사용 중인 아이디입니다.", **form)
    request.session["user_id"] = user_id
    return RedirectResponse("/", status_code=303)


@app.get("/logout")
def logout(request: Request):
    request.session.clear()
    return RedirectResponse("/login", status_code=303)


@app.get("/settings/password")
def password_page(request: Request):
    require_login(request)
    return render(request, "password.html")


@app.post("/settings/password")
def change_password(request: Request, current: str = Form(...), new: str = Form(...), confirm: str = Form(...)):
    me = require_login(request)
    user = query("SELECT password_hash FROM `User` WHERE user_id = %s", (me,), one=True)
    if not check_password(current, user["password_hash"]):
        return render(request, "password.html", error="현재 비밀번호가 올바르지 않습니다.")
    if len(new) < 4:
        return render(request, "password.html", error="새 비밀번호는 4자 이상이어야 합니다.")
    if new != confirm:
        return render(request, "password.html", error="새 비밀번호가 서로 다릅니다.")
    execute("UPDATE `User` SET password_hash = %s WHERE user_id = %s", (hash_password(new), me))
    request.session["flash"] = "비밀번호가 변경되었습니다."
    return RedirectResponse(f"/u/{me}", status_code=303)


# ---------------------------------------------------------------- feed & posts

@app.get("/")
def home(request: Request):
    me = require_login(request)
    # home feed: my posts + posts of users I follow, newest first
    posts = query(
        """SELECT p.post_id, p.author_id, p.image_path, p.caption, p.created_at, u.display_name
           FROM Post p JOIN `User` u ON u.user_id = p.author_id
           WHERE p.author_id = %s
              OR p.author_id IN (SELECT followee_id FROM Follow WHERE follower_id = %s)
           ORDER BY p.created_at DESC, p.post_id DESC
           LIMIT 50""",
        (me, me),
    )
    comments = comments_by_post([p["post_id"] for p in posts])
    texts = [p["caption"] for p in posts] + [c["text"] for cs in comments.values() for c in cs]
    suggestions = query(
        """SELECT u.user_id, u.display_name FROM `User` u
           WHERE u.user_id <> %s
             AND u.user_id NOT IN (SELECT followee_id FROM Follow WHERE follower_id = %s)
           ORDER BY RAND() LIMIT 5""",
        (me, me),
    )
    me_row = query("SELECT user_id, display_name FROM `User` WHERE user_id = %s", (me,), one=True)
    return render(request, "feed.html", posts=posts, comments=comments,
                  valid=existing_mentions(texts), suggestions=suggestions, me_row=me_row)


@app.get("/create")
def create_page(request: Request):
    require_login(request)
    return render(request, "create.html")


@app.post("/create")
async def create_post(request: Request, image: UploadFile = File(...), caption: str = Form("")):
    me = require_login(request)
    ext = Path(image.filename or "").suffix.lower()
    if ext not in ALLOWED_EXT:
        return render(request, "create.html", error="jpg, png, gif, webp 이미지만 올릴 수 있습니다.")
    data = await image.read()
    if not data or len(data) > MAX_UPLOAD:
        return render(request, "create.html", error="10MB 이하의 이미지를 선택하세요.")
    filename = f"{uuid.uuid4().hex}{ext}"
    (UPLOAD_DIR / filename).write_bytes(data)
    post_id = execute("INSERT INTO Post (author_id, image_path, caption) VALUES (%s, %s, %s)",
                      (me, f"uploads/{filename}", caption.strip() or None))
    return RedirectResponse(f"/p/{post_id}", status_code=303)


@app.get("/p/{post_id}")
def post_detail(request: Request, post_id: int):
    require_login(request)
    post = query(
        """SELECT p.post_id, p.author_id, p.image_path, p.caption, p.created_at, u.display_name
           FROM Post p JOIN `User` u ON u.user_id = p.author_id
           WHERE p.post_id = %s""",
        (post_id,), one=True,
    )
    if not post:
        return render(request, "not_found.html")
    comments = comments_by_post([post_id])[post_id]
    valid = existing_mentions([post["caption"]] + [c["text"] for c in comments])
    return render(request, "post.html", post=post, comments=comments, valid=valid)


@app.post("/p/{post_id}/comment")
def add_comment(request: Request, post_id: int, text: str = Form(...), next: str = Form("")):
    me = require_login(request)
    text = text.strip()
    if text:
        try:
            execute("INSERT INTO Comment (post_id, author_id, text) VALUES (%s, %s, %s)", (post_id, me, text))
        except IntegrityError:
            return render(request, "not_found.html")
    target = next if next.startswith("/") and not next.startswith("//") else f"/p/{post_id}"
    return RedirectResponse(target, status_code=303)


# ---------------------------------------------------------------- profiles & follow

def profile_header(me, user_id):
    user = query("SELECT user_id, display_name FROM `User` WHERE user_id = %s", (user_id,), one=True)
    if not user:
        return None
    counts = query(
        """SELECT (SELECT COUNT(*) FROM Post   WHERE author_id   = %s) AS posts,
                  (SELECT COUNT(*) FROM Follow WHERE followee_id = %s) AS followers,
                  (SELECT COUNT(*) FROM Follow WHERE follower_id = %s) AS following""",
        (user_id, user_id, user_id), one=True,
    )
    following = query("SELECT 1 FROM Follow WHERE follower_id = %s AND followee_id = %s",
                      (me, user_id), one=True) is not None
    return {**user, **counts, "is_following": following}


@app.get("/u/{user_id}")
def profile(request: Request, user_id: str):
    me = require_login(request)
    user = profile_header(me, user_id)
    if not user:
        return render(request, "not_found.html")
    posts = query(
        """SELECT p.post_id, p.image_path,
                  (SELECT COUNT(*) FROM Comment c WHERE c.post_id = p.post_id) AS comment_count
           FROM Post p WHERE p.author_id = %s
           ORDER BY p.created_at DESC, p.post_id DESC""",
        (user_id,),
    )
    return render(request, "profile.html", user=user, posts=posts)


@app.get("/u/{user_id}/followers")
def followers(request: Request, user_id: str):
    me = require_login(request)
    user = profile_header(me, user_id)
    if not user:
        return render(request, "not_found.html")
    people = query(
        """SELECT u.user_id, u.display_name,
                  EXISTS(SELECT 1 FROM Follow x WHERE x.follower_id = %s AND x.followee_id = u.user_id) AS i_follow
           FROM Follow f JOIN `User` u ON u.user_id = f.follower_id
           WHERE f.followee_id = %s ORDER BY u.user_id""",
        (me, user_id),
    )
    return render(request, "follow_list.html", user=user, people=people, title="팔로워")


@app.get("/u/{user_id}/following")
def following(request: Request, user_id: str):
    me = require_login(request)
    user = profile_header(me, user_id)
    if not user:
        return render(request, "not_found.html")
    people = query(
        """SELECT u.user_id, u.display_name,
                  EXISTS(SELECT 1 FROM Follow x WHERE x.follower_id = %s AND x.followee_id = u.user_id) AS i_follow
           FROM Follow f JOIN `User` u ON u.user_id = f.followee_id
           WHERE f.follower_id = %s ORDER BY u.user_id""",
        (me, user_id),
    )
    return render(request, "follow_list.html", user=user, people=people, title="팔로잉")


def safe_next(next, fallback):
    return next if next.startswith("/") and not next.startswith("//") else fallback


@app.post("/u/{user_id}/follow")
def follow(request: Request, user_id: str, next: str = Form("")):
    me = require_login(request)
    if user_id != me:
        try:
            # no approval needed: insert directly
            execute("INSERT IGNORE INTO Follow (follower_id, followee_id) VALUES (%s, %s)", (me, user_id))
        except IntegrityError:
            pass
    return RedirectResponse(safe_next(next, f"/u/{user_id}"), status_code=303)


@app.post("/u/{user_id}/unfollow")
def unfollow(request: Request, user_id: str, next: str = Form("")):
    me = require_login(request)
    execute("DELETE FROM Follow WHERE follower_id = %s AND followee_id = %s", (me, user_id))
    return RedirectResponse(safe_next(next, f"/u/{user_id}"), status_code=303)


# ---------------------------------------------------------------- search (bonus)

@app.get("/search")
def search(request: Request, q: str = ""):
    me = require_login(request)
    q = q.strip()
    people = []
    if q:
        like = f"%{q}%"
        people = query(
            """SELECT u.user_id, u.display_name,
                      EXISTS(SELECT 1 FROM Follow x WHERE x.follower_id = %s AND x.followee_id = u.user_id) AS i_follow
               FROM `User` u
               WHERE u.user_id LIKE %s OR u.display_name LIKE %s
               ORDER BY u.user_id LIMIT 30""",
            (me, like, like),
        )
    return render(request, "search.html", q=q, people=people)
