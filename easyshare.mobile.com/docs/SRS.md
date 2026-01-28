# EasyShare SRS

## 1. Purpose
EasyShare enables fast file transfer between two Android devices over the same Wi‑Fi network using QR codes. The sender hosts a local HTTP server and shows a QR; the receiver scans the QR, downloads files, and saves them to Downloads.

## 2. Scope
- Platform: Android (primary), Flutter app with GetX routing
- Transfer method: local Wi‑Fi HTTP server with QR invitation
- File types: any file supported by Android storage
- Multi-file transfers supported

## 3. Definitions
- Sender: device hosting files and QR
- Receiver: device scanning QR and downloading
- Transfer URL: local HTTP endpoint with token

## 4. Overall Description
### 4.1 Product Perspective
A standalone Flutter app. No backend service. Requires both devices on the same Wi‑Fi.

### 4.2 User Classes
- General users who want quick offline file sharing between phones

### 4.3 Operating Environment
- Android 9+ recommended (Android 10+ preferred for MediaStore saving)
- Same Wi‑Fi network for both devices

### 4.4 Constraints
- Receiver must access sender’s LAN IP
- App requires camera permission for QR scanning
- Saving to Downloads uses MediaStore on Android 10+

### 4.5 Assumptions
- Users grant required permissions
- Wi‑Fi network allows local device-to-device traffic

## 5. Functional Requirements
### FR‑1 Home
- Show app brand, value proposition, and actions to Send/Receive
- Provide clear guidance that both devices must be on same Wi‑Fi

### FR‑2 Send Flow
- Allow user to pick one or multiple files from storage
- Start local HTTP server bound to Wi‑Fi IP
- Generate a QR code containing the transfer URL + token
- Show selected files list and transfer status

### FR‑3 Receive Flow
- Open camera scanner and detect QR codes
- Parse URL + token from QR
- Fetch file metadata from sender
- Download each file with progress indicators
- Save files into Downloads
- Show per-file progress and overall progress

### FR‑4 Permissions
- Request camera permission for scanning
- Request storage permission on Android < 10 if needed
- Use MediaStore on Android 10+ to save to Downloads

### FR‑5 Error Handling
- Show user-friendly status when:
  - QR data is invalid
  - Sender not reachable
  - Download fails
  - Storage save fails

## 6. Non‑Functional Requirements
- Transfers occur locally without external servers
- UI is responsive on phones and tablets
- Transfer UI updates in real time
- Simple, minimal steps to complete a transfer

## 7. External Interface Requirements
- QR display and scanning
- File picker for multi-select
- Downloads storage via MediaStore or legacy storage

## 8. Data Requirements
- File metadata: id, name, size
- Transfer token: random string

## 9. Screens Spec (UI/UX)
### 9.1 Home
- Hero header with brand logo
- Two primary action cards: Send Files / Receive Files
- “How it works” steps section
- Wi‑Fi requirement hint banner
- Smooth page-load reveals for content blocks

### 9.2 Send Screen
- Top bar with back + logo + title
- Status banner (server status + file count)
- QR card with title, QR image, and URL text
- Selected files list with file icon and size

### 9.3 Receive Screen (Scanning)
- Top bar with back + logo + title
- Full camera view with rounded frame overlay
- Status text under scanner

### 9.4 Receive Screen (Downloading)
- Summary card with overall progress bar
- Per-file cards with filename and progress bar
- Footer text indicating “Saving to Downloads”

## 10. Future Enhancements
- Manual URL input as fallback
- Hotspot mode
- Wi‑Fi Direct or BLE fallback
- Transfer resume and verification
