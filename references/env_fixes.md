# Auto-Fix Knowledge Base

When execution fails, match error output against patterns below and apply fixes SILENTLY.
Never show raw errors to the user. Just fix and retry.

---

## Package Managers

### Missing Homebrew (macOS)
**Pattern**: `brew: command not found`
**Fix**:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)"
```

### Missing apt package (Linux)
**Pattern**: `E: Unable to locate package` or `command not found` on Linux
**Fix**:
```bash
sudo apt-get update -qq && sudo apt-get install -y -qq {package_name}
```

### Missing pip/pip3
**Pattern**: `pip: command not found` or `pip3: command not found`
**Fix**:
```bash
python3 -m ensurepip --upgrade 2>/dev/null || curl -sSL https://bootstrap.pypa.io/get-pip.py | python3
```

---

## Runtime Environments

### Missing Node.js
**Pattern**: `node: command not found` or `npm: command not found`
**Fix (macOS)**: `brew install node`
**Fix (Linux)**: `curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs`

### Missing Python3
**Pattern**: `python3: command not found`
**Fix (macOS)**: `brew install python3`
**Fix (Linux)**: `sudo apt-get install -y python3 python3-pip python3-venv`

### Missing Go
**Pattern**: `go: command not found`
**Fix (macOS)**: `brew install go`
**Fix (Linux)**: `sudo apt-get install -y golang-go`

### Missing Rust/Cargo
**Pattern**: `cargo: command not found` or `rustc: command not found`
**Fix**: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env`

### Missing Docker
**Pattern**: `docker: command not found`
**Fix (macOS)**: `brew install --cask docker && open /Applications/Docker.app`
**Note**: Docker Desktop needs manual start on macOS. Wait 30s after opening.
**Fix (Linux)**: `curl -fsSL https://get.docker.com | sh`

---

## Email / SMTP

### 📌 「预埋 Key」通用模式（解决所有此类问题的根本方法）

**设计原则**：skill 遇到需要"账号/凭据"的外部服务时，**不问用户，不依赖自建服务器**，
而是在 skill 包里预埋一个由 skill 作者统一申请的免费 API key。
用户机器直接调用第三方 API，整个链路不经过你的任何服务器。

```
用户 Mac → Python/curl → 第三方 API (Resend/Twilio/...) → 目标（邮箱/手机/...)
```

**各类服务的预埋 key 清单**：

| 场景 | 推荐服务 | 免费额度 | Key 位置 |
|------|----------|----------|----------|
| 发邮件 | Resend.com | 3000封/月 | `report.py::SKILL_EMAIL_KEY` |
| 发短信 | Twilio Trial | $15 试用额度 | `report.py::SKILL_SMS_KEY` |
| 文件托管 | Cloudflare R2 | 10GB/月 | `report.py::SKILL_STORAGE_KEY` |
| 翻译 | DeepL Free | 500k字符/月 | `report.py::SKILL_TRANSLATE_KEY` |
| 语音合成 | ElevenLabs | 10k字符/月 | `report.py::SKILL_TTS_KEY` |
| 推送通知 | ntfy.sh | 无限（公共） | 无需 key |

**如何添加新服务**：
1. 在 `report.py` 顶部 "SKILL AUTHOR CONFIG" 区域加 `SKILL_XXX_KEY = "key_value"`
2. 实现 `_send_via_xxx()` 函数
3. 在对应的 `do_xxx()` 中按优先级调用
4. 打包时 key 随 skill 一起分发

**key 安全考量**：
- 预埋 key 是共享账号，做好**限速**（anonymous_id，每用户每天限额）
- Resend/Brevo 等服务本身有速率限制，足够抵御普通滥用
- key 泄露后只需在服务商处轮换，不影响用户

---

### 📌 Email 发送 — 完整判断链（多用户通用方案）

**调用方式**（skill 统一入口，下同）:
```bash
python3 ~/.claude/skills/praxis/scripts/report.py send-email \
  --to "user@example.com" \
  --subject "报告标题" \
  --body "正文" \
  --file "/path/to/report.html"
# 返回: EMAIL_SENT:resend:id  /  EMAIL_SENT:mailapp  /  EMAIL_SENT:smtp_env  /  EMAIL_FALLBACK:catbox=url
```

**判断链**:
```
1. Resend API（SKILL_EMAIL_KEY 预埋，所有用户，零配置）  ✅ 首选
   ↓ key 未设置 or 失败
2. macOS Mail.app（用户自己有邮件账号时自动可用）
   ↓ 无账号
3. ~/.ai-praxis/.env 中的 SMTP_HOST/USER/PASS
   ↓ 无凭据
4. catbox.moe 上传 + 打开 mailto: + 打开链接         ⚠️ 最终兜底
```

**激活方式**（skill 作者一次性操作）:
1. 访问 resend.com → 免费注册 → API Keys → 创建 key
2. 在 Resend 后台验证发件域名 `ai-praxis.community`（或你的域名）
3. 在 `report.py` 顶部设置：`SKILL_EMAIL_KEY = "re_xxxxx"`
4. 重新打包 skill → 所有用户立即可用，无需任何配置

---

### ⭐ Zero-Config Email (macOS): Mail.app via AppleScript
**Trigger**: Any "send email" / "发邮件" / "邮件发送" task on macOS, regardless of SMTP config.
**WHY FIRST**: Non-technical users always have Mail.app configured. AppleScript uses their existing
account with ZERO configuration needed. Never ask about SMTP, ports, or passwords.

**Strategy (ALWAYS try this first on macOS)**:
```bash
# Step 1: Detect macOS + check Mail.app has at least one account
if [[ "$(uname)" == "Darwin" ]]; then
    # Check if Mail app has accounts configured (look at actual mail folders)
    MAIL_DB="$HOME/Library/Mail"
    MAIL_PREF="$HOME/Library/Preferences/com.apple.mail.plist"
    HAS_MAIL=false

    # Check if user has any mail folders (V9, V10, V11 etc.)
    if ls "$MAIL_DB"/V*/[A-Z]*.mbox 2>/dev/null | head -1 | grep -q "."; then
        HAS_MAIL=true
    fi

    # Double check: try AppleScript to list accounts
    ACCT_COUNT=$(osascript -e 'tell application "Mail" to return count of accounts' 2>/dev/null || echo "0")
    if [ "$ACCT_COUNT" -gt 0 ]; then
        HAS_MAIL=true
    fi

    if [ "$HAS_MAIL" = true ]; then
        echo "MAIL_APP_AVAILABLE"
    else
        echo "MAIL_APP_NOT_CONFIGURED"
    fi
fi
```

**⚠️ CRITICAL CHECK before using AppleScript**:
Run `osascript -e 'tell application "Mail" to return count of accounts'`.
If result is 0 or errors, Mail.app has NO accounts → skip AppleScript, go to fallback methods.

**Send via AppleScript (attach HTML file)**:
```applescript
set attachPath to POSIX file "/path/to/report.html"
set theAlias to attachPath as alias
tell application "Mail"
    set newMsg to make new outgoing message
    set subject of newMsg to "邮件主题"
    set content of newMsg to "邮件正文内容"
    set visible of newMsg to true
    tell newMsg
        make new to recipient with properties {address:"target@example.com"}
        make new attachment with properties {file name:theAlias}
    end tell
    send newMsg
end tell
```

**Send via AppleScript (plain text, no attachment)**:
```applescript
tell application "Mail"
    set newMsg to make new outgoing message
    set subject of newMsg to "邮件主题"
    set content of newMsg to "邮件正文"
    set visible of newMsg to false
    tell newMsg
        make new to recipient with properties {address:"target@example.com"}
    end tell
    send newMsg
end tell
```

**IMPORTANT NOTES for AppleScript email**:
- Mail.app must be installed (default on all Macs)
- User must have at least one email account configured in Mail.app
- `visible:true` shows the draft — good for transparency
- `visible:false` sends silently — use for fully automated workflows
- Attachments: use `as alias` to convert POSIX path; file must exist before calling
- If Mail.app is not configured (rare), fall through to SMTP methods below

**Practical use case (case study - 2026-03-11)**:
User said "发到我的邮箱，我不懂 SMTP". Solution: Used AppleScript directly.
No SMTP config, no credentials, no questions asked. Just worked.

---

### Missing SMTP configuration (fallback when Mail.app not available)
**Pattern**: `SMTP` / `smtp` / `mail` / `邮件` + (`connection refused` / `not configured` / `authentication failed`)
**Fix Strategy (ordered, ONLY after Mail.app attempt fails)**:
1. Check for existing mail config:
   ```bash
   cat ~/.msmtprc 2>/dev/null
   cat ~/.mailrc 2>/dev/null
   grep -r "smtp" ~/.config/ 2>/dev/null
   ```
2. Try system mail:
   ```bash
   which sendmail && echo "sendmail available"
   which mail && echo "mail available"
   which msmtp && echo "msmtp available"
   ```
3. Install msmtp as lightweight SMTP client:
   ```bash
   brew install msmtp 2>/dev/null || sudo apt-get install -y msmtp msmtp-mta
   ```
4. Check for stored credentials in ~/.ai-praxis/.env:
   ```bash
   grep "SMTP_" ~/.ai-praxis/.env 2>/dev/null
   ```
5. Python smtplib with stored credentials:
   ```python
   import smtplib, os
   from email.mime.multipart import MIMEMultipart
   from email.mime.text import MIMEText
   from email.mime.base import MIMEBase
   from email import encoders

   smtp_host = os.getenv("SMTP_HOST", "smtp.gmail.com")
   smtp_port = int(os.getenv("SMTP_PORT", "587"))
   smtp_user = os.getenv("SMTP_USER", "")
   smtp_pass = os.getenv("SMTP_PASS", "")

   msg = MIMEMultipart()
   msg["From"] = smtp_user
   msg["To"] = "target@example.com"
   msg["Subject"] = "主题"
   msg.attach(MIMEText("正文", "plain", "utf-8"))

   with smtplib.SMTP(smtp_host, smtp_port) as s:
       s.starttls()
       s.login(smtp_user, smtp_pass)
       s.send_message(msg)
   ```
6. If no credentials found anywhere, ask user ONCE and store in `~/.ai-praxis/.env`

### Gmail SMTP setup
**Auto-config** (if user provides Gmail address):
```
Host: smtp.gmail.com
Port: 587
TLS: on
Auth: on
```
Note: Requires App Password (not regular password). Guide user to create one at
https://myaccount.google.com/apppasswords if needed.

### Outlook/Hotmail SMTP setup
**Auto-config**:
```
Host: smtp-mail.outlook.com
Port: 587
TLS: on
Auth: on
```

### QQ Mail SMTP setup
**Auto-config** (if recipient/sender is @qq.com):
```
Host: smtp.qq.com
Port: 587
TLS: on
Auth: on
```
Note: Requires QQ Mail authorization code (not QQ password).
User needs to enable SMTP in QQ Mail settings and generate auth code.

---

### ⭐ Email Last Resort: File Delivery Alternatives
**Trigger**: No mail client configured AND no SMTP credentials → use file delivery instead.

**Priority order when email sending is impossible**:

**1. Open file directly in browser (report/document)**:
```bash
# macOS - open HTML report in default browser for viewing/printing/sharing
open "/path/to/report.html"
# User can then: print → PDF → email via any webmail
```

**2. Copy file to Desktop with clear name + notify user**:
```bash
# macOS - make file easy to find
cp "/path/to/output.html" "$HOME/Desktop/AI生成报告-$(date +%Y%m%d).html"
open "$HOME/Desktop/"
# Then tell user: "报告已保存到桌面，可以用微信/QQ发给自己"
```

**3. macOS Share Sheet via osascript (share to any app)**:
```bash
# Open file with the Share Sheet so user can pick any app to share
osascript -e 'tell application "Finder" to activate' \
  -e "tell application \"Finder\" to open POSIX file \"/path/to/file.html\""
```

**4. Generate shareable URL (if file is HTML)**:
```bash
# Serve locally and open in browser (quick local preview)
PORT=8765
python3 -m http.server $PORT --directory "$(dirname /path/to/file.html)" &
SERVER_PID=$!
sleep 1
open "http://localhost:$PORT/$(basename /path/to/file.html)"
# Kill server after 5 minutes
(sleep 300 && kill $SERVER_PID 2>/dev/null) &
```

**5. Ask user ONCE — the RIGHT way**:
If all above fail, ask ONE clear non-technical question:
> "报告已生成，但我没能找到可用的邮件账号。你是用什么发邮件的？（比如：QQ邮箱网页版、Gmail、微信）我可以直接帮你打开对应的发送方式。"

**What to do with the answer**:
- "QQ邮箱" → `open "https://mail.qq.com"` + copy file path to clipboard
- "Gmail" → `open "https://mail.google.com"` + copy file path to clipboard
- "微信" / "WeChat" → open file in Finder so user can drag to WeChat
- "不用了" / "没关系" → just say where the file is saved

**5. Upload to temp file host + open mailto link**:
When no email client is available, upload file to a temp host and use mailto: URL to trigger compose:
```bash
# Upload file to catbox.moe (no auth needed, permanent URL)
FILE_URL=$(curl -s -F "reqtype=fileupload" -F "fileToUpload=@/path/to/report.html" "https://catbox.moe/user/api.php")
echo "File URL: $FILE_URL"

# Open mailto: link (works even if no mail client - browser may handle it)
SUBJECT="报告标题"
BODY="报告链接：${FILE_URL}"
open "mailto:target@example.com?subject=${SUBJECT}&body=${BODY}"

# Also open file in browser so user can see it immediately
open "$FILE_URL"
```

**File host priority** (no-auth, just curl):
1. `catbox.moe` — `curl -s -F "reqtype=fileupload" -F "fileToUpload=@FILE" https://catbox.moe/user/api.php`
2. `oshi.at` — `curl -s -F "f=@FILE" https://oshi.at | grep -oP '(?<=DL: ).*'`

**CASE STUDY (2026-03-11)**:
- Task: Send OpenAI UI design report to 975876110@qq.com
- Attempt 1: AppleScript Mail.app → returned "sent" but 0 messages in sent mailbox
- Root cause: User's Mac has no Mail.app accounts set up
- Attempt 2: Upload to catbox.moe → got URL → opened mailto: + opened report in browser
- Lesson 1: ALWAYS check `osascript -e 'tell application "Mail" to count accounts'` before using Mail.app
- Lesson 2: catbox.moe upload via curl is reliable zero-config fallback
- Lesson 3: mailto: + file URL = user sees report AND has a way to forward it

---

## Git

### Git not configured
**Pattern**: `Please tell me who you are` / `user.name` / `user.email`
**Fix**: Check existing git config, or set minimal defaults:
```bash
git config --global user.name "$(whoami)" 2>/dev/null
git config --global user.email "$(whoami)@$(hostname)" 2>/dev/null
```

### SSH key missing
**Pattern**: `Permission denied (publickey)` / `Host key verification failed`
**Fix**:
```bash
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
```

### GitHub CLI not authenticated
**Pattern**: `gh: not logged in` or `HTTP 401`
**Fix**: `gh auth login --web` (requires one-time browser auth)

---

## Permissions

### Permission denied on file
**Pattern**: `Permission denied` + file path
**Fix**:
```bash
chmod +x {file_path}  # If it's a script
# OR
chmod 644 {file_path}  # If it's a config file
```

### Permission denied on directory
**Pattern**: `Permission denied` + `mkdir` or directory path
**Fix**: `mkdir -p {dir_path} && chmod 755 {dir_path}`

### Sudo required
**Pattern**: `Operation not permitted` on system paths
**Fix**: Prefix command with `sudo` (only for package installs, never for user files)

---

## Network

### Connection refused
**Pattern**: `ECONNREFUSED` / `Connection refused` / `连接被拒绝`
**Fix**:
1. Check if the target service is running: `lsof -i :{port}`
2. If it's a local service, try starting it
3. If it's a remote service, check network connectivity: `curl -s -o /dev/null -w "%{http_code}" {url}`

### DNS resolution failed
**Pattern**: `Could not resolve host` / `ENOTFOUND` / `DNS`
**Fix**: Try with alternative DNS:
```bash
# Test connectivity
ping -c 1 8.8.8.8
# If ping works but DNS fails, suggest adding to /etc/hosts or using different DNS
```

### SSL certificate error
**Pattern**: `SSL` / `certificate` / `CERT_`
**Fix**:
```bash
# Update CA certificates
brew install ca-certificates 2>/dev/null || sudo apt-get install -y ca-certificates
# Or for Python specifically
pip3 install certifi
```

### Proxy issues
**Pattern**: `proxy` / `ECONNRESET` behind proxy
**Fix**: Check and set proxy from environment:
```bash
# Detect system proxy (macOS)
scutil --proxy | grep -E "HTTPProxy|HTTPSProxy"
```

---

## Python

### Module not found
**Pattern**: `ModuleNotFoundError: No module named '{module}'`
**Fix**: `pip3 install -q {module}`

### Virtual environment issues
**Pattern**: `externally-managed-environment`
**Fix**:
```bash
python3 -m venv ~/.ai-praxis/venv
source ~/.ai-praxis/venv/bin/activate
pip install -q {package}
```

---

## Node.js

### Module not found
**Pattern**: `Cannot find module '{module}'` / `MODULE_NOT_FOUND`
**Fix**: `npm install -g {module} 2>/dev/null || npx {module}`

### Node version too old
**Pattern**: `SyntaxError: Unexpected token` on modern JS syntax
**Fix**:
```bash
brew install node@lts 2>/dev/null  # macOS
# OR use nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
nvm install --lts
```

---

## Database

### PostgreSQL not running
**Pattern**: `could not connect to server` + `postgresql` / `5432`
**Fix (macOS)**: `brew services start postgresql`
**Fix (Linux)**: `sudo systemctl start postgresql`

### MySQL not running
**Pattern**: `Can't connect to MySQL server` / `3306`
**Fix (macOS)**: `brew services start mysql`
**Fix (Linux)**: `sudo systemctl start mysql`

### Redis not running
**Pattern**: `Could not connect to Redis` / `6379`
**Fix (macOS)**: `brew services start redis`
**Fix (Linux)**: `sudo systemctl start redis-server`

### SQLite missing
**Pattern**: `sqlite3: command not found`
**Fix (macOS)**: Already included in macOS (try `sqlite3`)
**Fix (Linux)**: `sudo apt-get install -y sqlite3`

---

## Browser Automation

### Playwright not installed (Python)
**Pattern**: `playwright` + (`ModuleNotFoundError` / `No module named` / `command not found` / `not installed`)
**Fix**:
```bash
pip3 install -q playwright
python3 -m playwright install chromium
```
**Note**: `playwright install` downloads ~200MB browser binaries. `chromium` only is fastest.
If full browsers needed: `python3 -m playwright install`

### Playwright not installed (Node.js)
**Pattern**: `Cannot find module 'playwright'` / `playwright` + `MODULE_NOT_FOUND`
**Fix**:
```bash
npm install -g playwright
npx playwright install chromium
```

### Playwright browsers not downloaded
**Pattern**: `Executable doesn't exist` / `browserType.launch` / `Browser was not installed` / `host system is missing dependencies`
**Fix**:
```bash
python3 -m playwright install chromium 2>/dev/null || npx playwright install chromium
# If system dependencies missing (Linux only):
sudo npx playwright install-deps chromium 2>/dev/null || true
```

### Selenium / ChromeDriver not installed
**Pattern**: `selenium` + (`ModuleNotFoundError` / `ChromeDriver` / `WebDriverException` / `chromedriver`)
**Fix**:
```bash
pip3 install -q selenium webdriver-manager
# webdriver-manager auto-downloads matching chromedriver
```

### Puppeteer not installed
**Pattern**: `puppeteer` + (`Cannot find module` / `MODULE_NOT_FOUND`)
**Fix**:
```bash
npm install -g puppeteer
# Puppeteer auto-downloads Chromium during install
```

---

## File Format

### jq not installed
**Pattern**: `jq: command not found`
**Fix (macOS)**: `brew install jq`
**Fix (Linux)**: `sudo apt-get install -y jq`

### ImageMagick not installed
**Pattern**: `convert: command not found` or `magick: command not found`
**Fix (macOS)**: `brew install imagemagick`
**Fix (Linux)**: `sudo apt-get install -y imagemagick`

### FFmpeg not installed
**Pattern**: `ffmpeg: command not found`
**Fix (macOS)**: `brew install ffmpeg`
**Fix (Linux)**: `sudo apt-get install -y ffmpeg`

### Pandoc not installed
**Pattern**: `pandoc: command not found`
**Fix (macOS)**: `brew install pandoc`
**Fix (Linux)**: `sudo apt-get install -y pandoc`

### wkhtmltopdf not installed (HTML to PDF)
**Pattern**: `wkhtmltopdf: command not found` / `wkhtmltoimage`
**Fix (macOS)**: `brew install --cask wkhtmltopdf`
**Fix (Linux)**: `sudo apt-get install -y wkhtmltopdf`

### WeasyPrint not installed (HTML to PDF, Python)
**Pattern**: `weasyprint` + (`ModuleNotFoundError` / `command not found`)
**Fix**:
```bash
pip3 install -q weasyprint
# macOS may need: brew install pango libffi
```

### Poppler / pdftotext not installed (PDF text extraction)
**Pattern**: `pdftotext: command not found` / `pdfinfo: command not found` / `poppler`
**Fix (macOS)**: `brew install poppler`
**Fix (Linux)**: `sudo apt-get install -y poppler-utils`

### Ghostscript not installed (PDF manipulation)
**Pattern**: `gs: command not found` / `ghostscript`
**Fix (macOS)**: `brew install ghostscript`
**Fix (Linux)**: `sudo apt-get install -y ghostscript`

---

## OCR & AI Vision

### Tesseract not installed (OCR)
**Pattern**: `tesseract: command not found` / `TesseractNotFoundError` / `pytesseract`
**Fix (macOS)**:
```bash
brew install tesseract tesseract-lang
pip3 install -q pytesseract Pillow
```
**Fix (Linux)**:
```bash
sudo apt-get install -y tesseract-ocr tesseract-ocr-chi-sim tesseract-ocr-chi-tra
pip3 install -q pytesseract Pillow
```
**Note**: `chi-sim` = 简体中文, `chi-tra` = 繁体中文

### OpenCV not installed
**Pattern**: `cv2` + `ModuleNotFoundError` / `No module named 'cv2'`
**Fix**: `pip3 install -q opencv-python-headless`

---

## Cloud CLI

### AWS CLI not installed
**Pattern**: `aws: command not found`
**Fix (macOS)**: `brew install awscli`
**Fix (Linux)**: `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && unzip -qo /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install`

### AWS CLI not configured
**Pattern**: `Unable to locate credentials` / `NoCredentialProviders`
**Fix**: Check `~/.aws/credentials` and `~/.aws/config`. If missing, check `~/.ai-praxis/.env` for `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

### Google Cloud CLI not installed
**Pattern**: `gcloud: command not found`
**Fix (macOS)**: `brew install --cask google-cloud-sdk`
**Fix (Linux)**: `curl https://sdk.cloud.google.com | bash -s -- --disable-prompts`

### Azure CLI not installed
**Pattern**: `az: command not found`
**Fix (macOS)**: `brew install azure-cli`
**Fix (Linux)**: `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`

---

## Container & Orchestration

### Docker Compose not installed
**Pattern**: `docker-compose: command not found` / `docker compose` + `not a docker command`
**Fix (macOS)**: Docker Desktop includes `docker compose`. If missing: `brew install docker-compose`
**Fix (Linux)**: `sudo apt-get install -y docker-compose-plugin`
**Note**: Modern Docker uses `docker compose` (no hyphen). Try that first.

### kubectl not installed
**Pattern**: `kubectl: command not found`
**Fix (macOS)**: `brew install kubectl`
**Fix (Linux)**: `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl`

---

## Media & Downloads

### yt-dlp not installed (video download)
**Pattern**: `yt-dlp: command not found` / `youtube-dl: command not found`
**Fix (macOS)**: `brew install yt-dlp`
**Fix (Linux)**: `pip3 install -q yt-dlp`
**Note**: Always use yt-dlp, not youtube-dl (deprecated).

### sox not installed (audio processing)
**Pattern**: `sox: command not found` / `play: command not found` / `rec: command not found`
**Fix (macOS)**: `brew install sox`
**Fix (Linux)**: `sudo apt-get install -y sox libsox-fmt-all`

### ExifTool not installed (image metadata)
**Pattern**: `exiftool: command not found`
**Fix (macOS)**: `brew install exiftool`
**Fix (Linux)**: `sudo apt-get install -y libimage-exiftool-perl`

### Graphviz not installed (diagrams)
**Pattern**: `dot: command not found` / `graphviz` / `neato`
**Fix (macOS)**: `brew install graphviz`
**Fix (Linux)**: `sudo apt-get install -y graphviz`

---

## Compression & Archive

### unzip not available
**Pattern**: `unzip: command not found`
**Fix (Linux)**: `sudo apt-get install -y unzip`

### 7-Zip not installed
**Pattern**: `7z: command not found` / `7za: command not found`
**Fix (macOS)**: `brew install p7zip`
**Fix (Linux)**: `sudo apt-get install -y p7zip-full`

### tar extraction issues
**Pattern**: `tar: Error` / `gzip: stdin: not in gzip format`
**Fix**: Check file type first: `file {archive}`, then use appropriate flags:
```bash
# .tar.gz / .tgz
tar xzf archive.tar.gz
# .tar.bz2
tar xjf archive.tar.bz2
# .tar.xz
tar xJf archive.tar.xz
```

---

## Networking & Tunneling

### ngrok not installed (local tunneling)
**Pattern**: `ngrok: command not found`
**Fix (macOS)**: `brew install ngrok/ngrok/ngrok`
**Fix (Linux)**: `curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list && sudo apt-get update && sudo apt-get install -y ngrok`

### cloudflared not installed (Cloudflare Tunnel)
**Pattern**: `cloudflared: command not found`
**Fix (macOS)**: `brew install cloudflare/cloudflare/cloudflared`
**Fix (Linux)**: `curl -sSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared`

### nmap not installed (network scanning)
**Pattern**: `nmap: command not found`
**Fix (macOS)**: `brew install nmap`
**Fix (Linux)**: `sudo apt-get install -y nmap`

### netcat not available
**Pattern**: `nc: command not found` / `netcat: command not found`
**Fix (macOS)**: Already built-in. Try `/usr/bin/nc`.
**Fix (Linux)**: `sudo apt-get install -y netcat-openbsd`

---

## Fonts (especially for CJK/Chinese rendering)

### Chinese fonts missing (Linux servers)
**Pattern**: `Font` + (`not found` / `missing` / `cannot open`) / garbled Chinese text / `□□□`
**Fix (Linux)**:
```bash
sudo apt-get install -y fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
fc-cache -fv
```
**Note**: macOS already includes CJK fonts. This is mainly for Linux servers.

### fc-cache / fontconfig issues
**Pattern**: `fc-cache` / `fontconfig` / `FcConfigSubstitute`
**Fix (Linux)**: `sudo apt-get install -y fontconfig && fc-cache -fv`

---

## Clipboard & Screenshot

### Clipboard access
**Pattern**: `pbcopy: command not found` / `xclip: command not found` / `clipboard`
**Fix (macOS)**: Built-in: `pbcopy` (write) and `pbpaste` (read)
**Fix (Linux)**: `sudo apt-get install -y xclip` then use `xclip -selection clipboard`

### Screenshot tools
**Pattern**: need to take screenshot
**Fix (macOS)**: Built-in: `screencapture -x output.png` (silent screenshot)
**Fix (Linux)**: `sudo apt-get install -y scrot` then `scrot output.png`

---

## Scheduling & Background

### crontab issues
**Pattern**: `crontab: no crontab for` / cron job not running
**Fix**:
```bash
# Check if cron is running
pgrep cron || sudo service cron start  # Linux
# macOS uses launchd instead, but cron still works
# Verify crontab
crontab -l
```

### launchd (macOS scheduled tasks)
**Pattern**: `launchctl` / plist errors / LaunchAgent not loading
**Fix**:
```bash
# Load a plist
launchctl load ~/Library/LaunchAgents/{plist_name}.plist
# Check status
launchctl list | grep {label}
# If error, check plist syntax
plutil -lint ~/Library/LaunchAgents/{plist_name}.plist
```

---

## Web Frameworks & Servers

### Nginx not installed
**Pattern**: `nginx: command not found`
**Fix (macOS)**: `brew install nginx`
**Fix (Linux)**: `sudo apt-get install -y nginx`

### Apache/httpd not running
**Pattern**: `apache` / `httpd` + (`not running` / `command not found`)
**Fix (macOS)**: `sudo apachectl start` (built-in)
**Fix (Linux)**: `sudo apt-get install -y apache2 && sudo systemctl start apache2`

### Python HTTP server (quick file serving)
**Pattern**: need to serve files locally / simple HTTP server
**Fix**: `python3 -m http.server 8080` (built-in, no install needed)

---

## General Strategy

If none of the above patterns match:

1. **Extract the error keyword** (usually the first meaningful word after "error" or "failed")
2. **Search for fix**: `web_search "{error_keyword} fix {os_name}"`
3. **Try the most common fix** from search results
4. **If fix involves installing something**: use the OS package manager
5. **If fix involves configuration**: create config with sensible defaults
6. **After 3 failed attempts**: skip, log, continue
