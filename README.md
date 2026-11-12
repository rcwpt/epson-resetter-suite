# Epson Resetter Suite

<p align="center">
  <img src="https://img.shields.io/badge/Security-100%25%20Defender%20Clean-brightgreen?style=for-the-badge&logo=windows" alt="Defender Clean">
  <img src="https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue?style=for-the-badge&logo=windows11" alt="Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell" alt="PowerShell">
  <a href="https://www.instagram.com/c.wijaya.t">
    <img src="https://img.shields.io/badge/Instagram-@c.wijaya.t-E4405F?style=for-the-badge&logo=instagram&logoColor=white" alt="Instagram">
  </a>
</p>

A clean, consolidated **Epson Adjustment Program (Waste Ink Pad Counter Resetter)** suite with an interactive terminal interface. 100% sanitized from Trojans, malware, and malicious keygens, ready to launch with a single short PowerShell command straight from GitHub!

<p align="center">
  <b>Created with ❤️ by <a href="https://github.com/rcwpt">rcwpt</a></b> • 
  <b>Follow on Instagram: <a href="https://www.instagram.com/c.wijaya.t">@c.wijaya.t</a></b>
</p>

---

## ⚡ Quick Online Launch (Short One-Liner)

Open **PowerShell** (recommended: *Run as Administrator*), then copy and paste this command:

```powershell
irm tinyurl.com/rcwpt-epson | iex
```

*(Or with HTTPS prefix / full GitHub raw link):*
```powershell
irm https://tinyurl.com/rcwpt-epson | iex
# Direct GitHub:
irm https://raw.githubusercontent.com/rcwpt/epson-resetter-suite/main/get.ps1 | iex
```

> **Note:** The script will automatically verify privileges, download the lightweight clean suite (~26 MB), and launch the interactive terminal menu instantly.

---

## 🚀 Key Highlights & Features

1. **⚡ Smart 1-Click Instant Mode (Option `[A]`):**
   - **Specially built for non-tech-savvy users ("Orang Gaptek")!**
   - Automatically detects your connected Epson printer model and USB port.
   - Automatically clears stuck print jobs (spooler) to prevent Error `20000010`.
   - Checks if the official USB driver is installed; offers auto-install if missing.
   - Copies required passwords (e.g., `i-loadzone.com`) to your clipboard automatically.
   - Launches the exact matching Adjustment Program with a simple 4-step on-screen guide!
2. **Automated Driver Verification & On-Demand Downloader (Option `[V]`):**
   - Seamlessly fetches and installs official Epson drivers on-demand, resolving *"Port not recognized"* and *"Communication Error 21000068"*.
3. **Integrated Diagnostic Test Print (Option `[T]`):**
   - Directly linked with **[Printer Test Ultimate](https://github.com/rcwpt/printertestultimate)**. Prompts you automatically to run a full CMYK and nozzle test print as soon as you finish resetting!
4. **Clean & 100% Sanitized Binaries:**
   - All trojans, backdoors, and suspicious keygens from public sources have been eliminated. Verified with Microsoft Defender Antivirus:
     ```text
     Scanning C:\...\epson-resetter-suite\bin found no threats.
     ```
5. **Print Spooler Repair (Option `[S]`):**
   - One-click tool to terminate `spoolsv`, clear locked spooler queues in `C:\Windows\System32\spool\PRINTERS`, and restart the service.

---

## 🖨️ Supported Epson Printer Series

| Series Category | Supported Models | Binary Status |
| :--- | :--- | :--- |
| **EcoTank L-Series Classic** | L110, L210, L300, L350, L355 | 🟢 100% Clean |
| **EcoTank L120** | L120 (Patched Edition - Ready to use) | 🟢 100% Clean |
| **EcoTank L130 - L365** | L130, L220, L310, L360, L365 | 🟢 100% Clean |
| **EcoTank L500 Series** | L565 | 🟢 100% Clean |
| **EcoTank Modern Family** | L1210, L3210, L3250, L3251, L3260, L5290 | 🟢 100% Clean *(Auto-Clipboard: `i-loadzone.com`)* |
| **EcoTank L6000 Series** | L6161, L6171, L6091 | 🟢 100% Clean |

---

## 📖 How to Reset in 4 Simple Steps

```
┌────────────────────────────────────────────────────────────────────────┐
│                 FOOLPROOF 4-STEP RESET INSTRUCTIONS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. In the program window, click [Particular adjustment mode].          │
│ 2. Double-click [Waste ink pad counter] in the Maintenance list.       │
│ 3. Check the box [Main pad counter], then click [Initialize].          │
│ 4. Turn OFF the printer with power button when prompted, then turn ON! │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 👤 Author & Credits

- **Developer**: [rcwpt](https://github.com/rcwpt)
- **Instagram**: [@c.wijaya.t](https://www.instagram.com/c.wijaya.t)
- **Watermark**: *Created with love by rcwpt*

Feel free to connect or send a DM on Instagram if you find this project helpful!

---

## ⚖️ Disclaimer

This repository is intended strictly for educational purposes, Right to Repair maintenance, and security research. All trademarks, service marks, and company names are the property of Seiko Epson Corporation.
