# Epson Resetter All-In-One Suite (MAS-Style CLI/GUI)

<p align="center">
  <img src="https://img.shields.io/badge/Security-100%25%20Defender%20Clean-brightgreen?style=for-the-badge&logo=windows" alt="Defender Clean">
  <img src="https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue?style=for-the-badge&logo=windows11" alt="Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell" alt="PowerShell">
  <a href="https://www.instagram.com/c.wijaya.t">
    <img src="https://img.shields.io/badge/Instagram-@c.wijaya.t-E4405F?style=for-the-badge&logo=instagram&logoColor=white" alt="Instagram">
  </a>
</p>

A clean, consolidated **Epson Adjustment Program (Waste Ink Pad Counter Resetter)** suite with an interactive **CLI/GUI terminal** inspired by [massgravel.dev (MAS)](https://massgrave.dev). 100% sanitized from Trojans, malware, and malicious keygens, ready to launch with a single short PowerShell command straight from GitHub!

<p align="center">
  <b>Created with ❤️ by <a href="https://github.com/rcwpt">rcwpt</a></b> • 
  <b>Follow on Instagram: <a href="https://www.instagram.com/c.wijaya.t">@c.wijaya.t</a></b>
</p>

---

## ⚡ Quick Online Launch (Short One-Liner ala MAS)

Open **PowerShell** (recommended: *Run as Administrator*), then copy and paste this short command:

```powershell
irm tinyurl.com/rcwpt-epson | iex
```

*(Or with HTTPS prefix / full GitHub raw link):*
```powershell
irm https://tinyurl.com/rcwpt-epson | iex
# Fallback Direct Link:
irm https://raw.githubusercontent.com/rcwpt/epson-resetter-suite/main/get.ps1 | iex
```

> **Note:** The script will automatically verify privileges, download the lightweight clean suite (~26 MB), and launch the interactive terminal menu instantly.

---

## 💻 Manual Offline Run (Portable)

1. Clone this repository or download the ZIP archive from **Code > Download ZIP**:
   ```bash
   git clone https://github.com/rcwpt/epson-resetter-suite.git
   cd epson-resetter-suite
   ```
2. Right-click **`Run.bat`** and select **Run as administrator** (or execute `powershell -ExecutionPolicy Bypass -File src\EpsonResetter.ps1`).

---

## 🛡️ Security Audit & Why This Suite Exists

Many technicians and users download resetters from public repositories or institutional servers (such as public `/resetter/` directories) that instruct users to *"Turn off Real-Time Protection"*.

Our forensic analysis with Microsoft Defender Antivirus revealed:
* **The original archives were heavily compromised**: Multiple active Trojans (**`Trojan:Win32/Vigorf.A`**, **`Trojan:Win32/Tiggre`**, and **`Trojan:Win32/Occamy!rfn`**) were embedded inside `Keygen.exe` files and dropper archives.
* **This suite is 100% sanitized**: All dangerous generators and backdoor payloads have been removed. Every executable in the `bin/` directory has been verified with Microsoft Defender:
  ```text
  Scanning C:\...\epson-resetter-suite\bin found no threats.
  ```
* Read the detailed forensic investigation in **[MALWARE_AUDIT.md](MALWARE_AUDIT.md)**.

---

## 🖨️ Supported Epson Printer Series

| Series Category | Supported Models | Binary Status |
| :--- | :--- | :--- |
| **EcoTank L-Series Classic** | L110, L210, L300, L350, L355 | 🟢 100% Clean |
| **EcoTank L120** | L120 (Cracked Edition - Ready to use) | 🟢 100% Clean |
| **EcoTank L130 - L365** | L130, L220, L310, L360, L365 | 🟢 100% Clean |
| **EcoTank L500 Series** | L565 | 🟢 100% Clean |
| **EcoTank Modern Family** | L1210, L3210, L3250, L3251, L3260, L5290 | 🟢 100% Clean *(Password: `i-loadzone.com`)* |
| **EcoTank L6000 Series** | L6161, L6171, L6091 | 🟢 100% Clean |

---

## 🚀 Key Highlights

1. **MAS-Inspired Terminal UI:**
   - Elegant terminal design with clear status indicators, numbered shortcuts, and automatic administrator detection.
2. **Auto-Detect Printer & USB Ports:**
   - Integrated Windows WMI and PnP hardware queries to detect active Epson printers and USB connection states in real time.
3. **Automated Print Spooler Fixer:**
   - Solves the infamous technician headache: **`Communication error! Error Code: 20000010`** and **`21000068`** by terminating `spoolsv`, purging locked print queue files in `C:\Windows\System32\spool\PRINTERS`, and restarting the spooler.
4. **Step-by-Step Guidance:**
   - Contextual on-screen instructions guide you through the exact reset procedure (Select Model -> Particular Adjustment Mode -> Waste ink pad counter -> Check & Initialize).

---

## 📖 Step-by-Step Waste Ink Pad Reset Guide

1. Turn ON the Epson printer and connect it directly via USB cable (avoid USB hubs and Wi-Fi).
2. Launch **Epson Resetter Suite** and pick your printer model number.
3. In the Adjustment Program window:
   - Click **[Select]** and select your model and USB port (e.g., *USB001*).
   - Click **[Particular adjustment mode]**.
   - Select **[Waste ink pad counter]** in the Maintenance list, then click **[OK]**.
   - Check the **Main pad counter** box (and *Platen pad counter* if present).
   - Click **[Check]** to inspect the current pad reading.
   - Click **[Initialize]** to reset the counter back to 0%.
4. When the pop-up says *"Please turn off the printer"*, turn OFF the printer using its physical power button.
5. Click **[OK]** on the dialog, wait 5 seconds, and turn the printer back ON. The alternating ink/paper blinking lights will stop, and the printer will be ready to print!

---

## 👤 Author & Credits

- **Developer**: [rcwpt](https://github.com/rcwpt)
- **Instagram**: [@c.wijaya.t](https://www.instagram.com/c.wijaya.t)
- **Watermark**: *Created with love by rcwpt*

Feel free to connect or send a DM on Instagram if you find this project helpful!

---

## ⚖️ Disclaimer

This repository is intended strictly for educational purposes, Right to Repair maintenance, and security research. All trademarks, service marks, and company names are the property of Seiko Epson Corporation.
