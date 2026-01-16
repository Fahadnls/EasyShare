# EasyShare 🚀

EasyShare is a **Flutter-based Android application** that enables **fast, offline file sharing** between two Android devices connected to the **same Wi‑Fi network**. It uses **QR codes** and a **local HTTP server** to transfer files securely without any backend or internet connection.

---

## ✨ Features

* 📡 **Local Wi‑Fi file transfer** (no internet required)
* 🔳 **QR code–based discovery**
* 📂 **Multi-file selection & transfer**
* 📊 **Real-time transfer progress** (per file & overall)
* 🔐 **Token-based secure transfer URLs**
* 💾 Saves files directly to **Downloads**
* ⚡ Fast, simple, and privacy-friendly

---

## 🧠 How It Works

1. Both devices connect to the **same Wi‑Fi network**
2. **Sender** selects one or more files
3. Sender starts a **local HTTP server** on LAN IP
4. App generates a **QR code** with transfer URL + token
5. **Receiver** scans the QR code
6. Receiver downloads files and saves them to **Downloads**

---

## 🛠 Tech Stack

* **Flutter** (Android-first)
* **GetX** – routing & state management
* **Local HTTP Server** (LAN-based)
* **QR Code** generation & scanning
* **MediaStore API** (Android 10+)
* Legacy storage support for Android < 10

---

## 📱 Platform Support

* Android 9+ (recommended)
* Android 10+ preferred for scoped storage

> ⚠️ Both devices must be on the **same Wi‑Fi network** and allow local device-to-device traffic.

---

## 🔐 Permissions Used

| Permission               | Purpose               |
| ------------------------ | --------------------- |
| Camera                   | QR code scanning      |
| Storage (Android < 10)   | Save downloaded files |
| MediaStore (Android 10+) | Save to Downloads     |

---

## 📂 App Screens

### 🏠 Home

* App branding & value proposition
* **Send Files** / **Receive Files** actions
* Wi‑Fi requirement hint

### 📤 Send Files

* File picker (multi-select)
* Server status banner
* QR code with transfer URL
* Selected files list with size

### 📥 Receive Files (Scan)

* Camera scanner with overlay
* QR detection status

### 📥 Receive Files (Download)

* Overall progress bar
* Per-file progress cards
* Status: “Saving to Downloads”

---

## ⚠️ Error Handling

EasyShare gracefully handles:

* ❌ Invalid or expired QR codes
* ❌ Sender not reachable on LAN
* ❌ Download interruptions
* ❌ Storage write failures

Clear user-friendly messages are shown for each case.

---

## 📦 Data Model

* **File Metadata**: `id`, `name`, `size`
* **Transfer Token**: Random secure string

---

## 🚧 Limitations

* Requires same Wi‑Fi network
* No background transfers
* No resume support (yet)

---

## 🔮 Future Enhancements

* ✍️ Manual URL input fallback
* 📶 Hotspot mode
* 🔄 Transfer resume & verification
* 📡 Wi‑Fi Direct support
* 🔵 BLE fallback discovery

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a Pull Request

---

## 📜 License

This project is licensed under the **MIT License**.

---

## 👤 Author

**Fahad Ayub**
Flutter & Android Developer

---

⭐ If you like this project, consider giving it a star on GitHub!
