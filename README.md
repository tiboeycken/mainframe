# 🖥️ OpsDash - Mainframe Dashboard

A modern, dual-mode dashboard system for z/OS mainframe monitoring and COBOL development.

## ✨ Features

- **Dual-Mode Operation:**
  - **USS Terminal Dashboard** (`opsdash.py`) - Runs on z/OS at login
  - **Web Dashboard** (`opsdash_web.py`) - Runs locally, connects via Zowe CLI

- **Real-Time Monitoring:**
  - System information (user, host, uptime, disk usage)
  - JES job status and tracking
  - Dataset inventory with PDS member listings

- **Integrated COBOL Development:**
  - Built-in COBOL editor
  - Upload to mainframe datasets
  - Compile & run with automatic JCL generation
  - Job status tracking and spool file viewing

- **Modern UI:**
  - Clean, responsive web interface (Streamlit)
  - Auto-refresh capabilities
  - Session persistence
  - Mobile-friendly

## 🚀 Quick Start

### Web Dashboard (Local Machine)

1. **Install Zowe CLI:**
   ```bash
   npm install -g @zowe/cli
   ```

2. **Configure Zowe CLI:**
   ```bash
   zowe zosmf check status
   # Follow prompts to enter host, port, user, password
   ```

3. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Run dashboard:**
   ```bash
   streamlit run opsdash_web.py
   ```

5. **Open browser:** `http://localhost:8501`

### USS Terminal Dashboard

1. **SSH into mainframe:**
   ```bash
   ssh user@mainframe
   ```

2. **Set environment variables:**
   ```bash
   export ZOWE_HOST=your-mainframe-host
   export ZOWE_PORT=10443
   export ZOWE_USER=your-userid
   export ZOWE_PASS=your-password
   ```

3. **Run dashboard:**
   ```bash
   python3 opsdash.py
   ```


## 📋 Requirements

- Python 3.8+
- Node.js 16+ (for Zowe CLI)
- Zowe CLI installed and configured
- Access to z/OSMF (z/OS Management Facility)
- Streamlit (for web dashboard)

## 📁 Project Structure

```
opsdash/
├── opsdash.py              # USS terminal dashboard
├── opsdash_web.py          # Web dashboard (Streamlit)
├── requirements.txt        # Python dependencies
├── README.md               # This file
└── .gitignore             # Git ignore rules
```

## 🛠️ Technologies Used

- **Python** - Core language
- **Streamlit** - Web framework
- **Zowe CLI** - Mainframe integration
- **JCL** - Job submission and COBOL compilation
- **COBOL** - Program development
- **USS** - Unix System Services
- **Bash** - Shell scripting

## 📖 Documentation

- [Grand Challenge Submission](GRAND_CHALLENGE_SUBMISSION.txt) - Submission details

## 🔧 Configuration

### Web Dashboard

- Use sidebar to set User ID and HLQ
- Defaults to your Zowe CLI profile user
- Click "Refresh All" to update data

### USS Dashboard

- Set environment variables for Zowe connection
- Modify `dataset_patterns` in `opsdash.py` to customize datasets shown
- Use `--no-pause` flag for non-interactive execution

## 🐛 Troubleshooting

### Zowe CLI Issues

```bash
# Test connection
zowe zosmf check status

# Check profile
zowe profiles list zosmf-profiles

# Update credentials
zowe profiles update zosmf-profile default
```

### Web Dashboard Issues

- **"Zowe not found"**: Ensure Zowe CLI is in PATH
- **"401 Authentication"**: Check Zowe credentials
- **"Connection timeout"**: Verify network access to mainframe

See [README_WEB.md](README_WEB.md) for detailed troubleshooting.

## 📝 License

This project was created for the IBM Z Grand Challenge.

## 🤝 Contributing

This is a Grand Challenge submission. Feel free to fork and adapt for your own use!

## 📸 Screenshots

*Add screenshots of your dashboard here*

## 🎯 Use Cases

- **System Administrators**: Monitor mainframe health and jobs
- **Developers**: Edit and test COBOL programs remotely
- **Operations**: Track job status and system resources
- **Learning**: Explore mainframe datasets and jobs

## 🔒 Security Notes

- Never commit credentials or passwords
- Use Zowe CLI profiles for authentication
- Keep `.zowe/` directory in `.gitignore`
- Use environment variables for sensitive data

---

**Built for IBM Z Grand Challenge 2025**

