#!/usr/bin/env python3
"""
OpsDash Enhanced for Raspberry Pi
Adds monitoring, logging, and notification features optimized for Pi deployment
"""

import streamlit as st
import subprocess
import json
import os
import platform
import shutil
import tempfile
from datetime import datetime, timedelta
import time
import sqlite3
from pathlib import Path

# Import original dashboard functions
import opsdash_web

# Page config
st.set_page_config(
    page_title="OpsDash Pi - Mainframe Dashboard",
    page_icon="🍓",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Add Pi-specific CSS
st.markdown(
    """
<style>
    .pi-status {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #00d26a;
        margin-bottom: 1rem;
    }
    .metric-card {
        background-color: #f8f9fa;
        padding: 0.75rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
</style>
""",
    unsafe_allow_html=True,
)


def get_pi_info():
    """Get Raspberry Pi system information."""
    info = {}
    
    try:
        # Check if running on Raspberry Pi
        with open('/proc/cpuinfo', 'r') as f:
            cpuinfo = f.read()
            if 'Raspberry Pi' in cpuinfo or 'BCM' in cpuinfo:
                info['is_pi'] = True
                
                # Get Pi model
                for line in cpuinfo.split('\n'):
                    if 'Model' in line or 'model name' in line:
                        info['model'] = line.split(':')[-1].strip()
                        break
            else:
                info['is_pi'] = False
    except:
        info['is_pi'] = False
    
    # CPU temperature (Pi specific)
    try:
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            temp = int(f.read()) / 1000.0
            info['cpu_temp'] = f"{temp:.1f}°C"
    except:
        info['cpu_temp'] = "N/A"
    
    # Uptime
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.read().split()[0])
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            info['uptime'] = f"{days}d {hours}h"
    except:
        info['uptime'] = "N/A"
    
    # Memory usage
    try:
        result = subprocess.run(['free', '-m'], capture_output=True, text=True)
        lines = result.stdout.split('\n')
        mem_line = lines[1].split()
        total_mem = int(mem_line[1])
        used_mem = int(mem_line[2])
        info['memory'] = f"{used_mem}MB / {total_mem}MB ({used_mem*100//total_mem}%)"
    except:
        info['memory'] = "N/A"
    
    # Disk usage
    try:
        result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
        lines = result.stdout.split('\n')
        if len(lines) > 1:
            parts = lines[1].split()
            info['disk'] = f"{parts[2]} / {parts[1]} ({parts[4]})"
    except:
        info['disk'] = "N/A"
    
    return info


def init_database():
    """Initialize SQLite database for metrics storage."""
    db_path = Path.home() / '.opsdash' / 'metrics.db'
    db_path.parent.mkdir(exist_ok=True)
    
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # Create tables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS job_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            job_id TEXT,
            job_name TEXT,
            status TEXT,
            return_code TEXT,
            user_id TEXT
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS system_checks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            zowe_status TEXT,
            mainframe_reachable INTEGER
        )
    ''')
    
    conn.commit()
    conn.close()
    return db_path


def log_job_status(job_id, job_name, status, return_code, user_id):
    """Log job status to database."""
    db_path = Path.home() / '.opsdash' / 'metrics.db'
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    cursor.execute('''
        INSERT INTO job_history 
        (timestamp, job_id, job_name, status, return_code, user_id)
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (datetime.now().isoformat(), job_id, job_name, status, 
          str(return_code), user_id))
    
    conn.commit()
    conn.close()


def get_recent_job_history(limit=20):
    """Get recent job history from database."""
    db_path = Path.home() / '.opsdash' / 'metrics.db'
    if not db_path.exists():
        return []
    
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT timestamp, job_id, job_name, status, return_code
        FROM job_history
        ORDER BY timestamp DESC
        LIMIT ?
    ''', (limit,))
    
    results = cursor.fetchall()
    conn.close()
    
    return results


def check_mainframe_connection():
    """Check if mainframe is reachable via Zowe."""
    try:
        zowe_exe = opsdash_web.find_zowe_executable()
        profile = opsdash_web.get_zowe_profile_name()
        
        result = subprocess.run(
            [zowe_exe, "zosmf", "check", "status", "--zosmf-profile", profile],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        return result.returncode == 0
    except:
        return False


# Main app
def main():
    # Initialize database
    init_database()
    
    # Header with Pi indicator
    pi_info = get_pi_info()
    
    if pi_info.get('is_pi'):
        st.markdown(
            '<p class="main-header">🍓 OpsDash Pi - Mainframe Dashboard</p>',
            unsafe_allow_html=True,
        )
        
        # Pi Status Section
        with st.expander("🖥️ Raspberry Pi Status", expanded=False):
            col1, col2, col3, col4 = st.columns(4)
            with col1:
                st.metric("CPU Temp", pi_info.get('cpu_temp', 'N/A'))
            with col2:
                st.metric("Uptime", pi_info.get('uptime', 'N/A'))
            with col3:
                st.metric("Memory", pi_info.get('memory', 'N/A').split('(')[0].strip())
            with col4:
                st.metric("Disk", pi_info.get('disk', 'N/A').split('(')[0].strip())
            
            # Connection status
            st.markdown("---")
            with st.spinner("Checking mainframe connection..."):
                mainframe_ok = check_mainframe_connection()
            
            if mainframe_ok:
                st.success("✅ Mainframe connection: OK")
            else:
                st.error("❌ Mainframe connection: FAILED")
    else:
        st.markdown(
            '<p class="main-header">🖥️ OpsDash - Mainframe Dashboard</p>',
            unsafe_allow_html=True,
        )
    
    # Sidebar with Pi enhancements
    with st.sidebar:
        st.header("Configuration")
        user_id = st.text_input("User ID", value="Z83570", help="Your z/OS user ID")
        hlq = st.text_input(
            "HLQ (High Level Qualifier)",
            value=user_id.upper(),
            help="Dataset high level qualifier",
        )
        
        # Auto-refresh option
        auto_refresh = st.checkbox("Auto-refresh (30s)", value=False)
        if auto_refresh:
            time.sleep(30)
            st.rerun()
        
        st.markdown("---")
        st.header("📊 Metrics")
        
        # Job History
        if st.button("📜 View Job History"):
            history = get_recent_job_history(10)
            if history:
                st.subheader("Recent Jobs")
                for timestamp, job_id, job_name, status, rc in history:
                    st.text(f"{timestamp[:19]} | {job_id} | {status} | RC: {rc}")
            else:
                st.info("No job history yet.")
        
        st.markdown("---")
        st.header("About")
        st.info(
            """
        **OpsDash Pi** provides:
        - Real-time mainframe monitoring
        - JES job tracking
        - COBOL development tools
        - System metrics logging
        
        Running on: Raspberry Pi 🍓
        """
        )
    
    # Call original dashboard main function
    # We'll integrate the original dashboard here
    # For now, let's add a tab structure
    
    tab1, tab2, tab3 = st.tabs(["📊 Dashboard", "💻 COBOL Dev", "📈 Analytics"])
    
    with tab1:
        # System Info Section (enhanced)
        st.header("📊 System Summary")
        sys_info = opsdash_web.get_system_info()
        
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("User", sys_info["user"])
        with col2:
            st.metric("Host", sys_info["host"])
        with col3:
            st.metric("Current Time", sys_info["time"])
        
        st.markdown("---")
        
        # Jobs Section (from original)
        st.header("📋 JES Jobs")
        
        with st.spinner("Fetching jobs..."):
            jobs = opsdash_web.get_user_jobs(user_id)
        
        if isinstance(jobs, dict) and "error" in jobs:
            st.error(f"❌ Error retrieving jobs: {jobs['error']}")
            st.info("💡 Make sure Zowe CLI is configured and you're authenticated.")
        elif not jobs:
            st.info("No jobs found for this user.")
        else:
            # Job statistics
            status_counts = {}
            for job in jobs:
                status = job.get("status", "UNKNOWN")
                status_counts[status] = status_counts.get(status, 0) + 1
            
            if status_counts:
                cols = st.columns(len(status_counts))
                for idx, (status, count) in enumerate(status_counts.items()):
                    with cols[idx]:
                        st.metric(status, count)
            
            # Log jobs to database
            for job in jobs:
                log_job_status(
                    job.get("jobid") or job.get("jobId", ""),
                    job.get("jobname") or job.get("jobName", ""),
                    job.get("status", ""),
                    job.get("retcode") or job.get("retCode", ""),
                    user_id
                )
            
            # Jobs table
            st.subheader("Job Details")
            job_data = []
            for job in jobs:
                job_data.append({
                    "Job Name": job.get("jobname") or job.get("jobName", ""),
                    "Job ID": job.get("jobid") or job.get("jobId", ""),
                    "Status": job.get("status", ""),
                    "Owner": job.get("owner", ""),
                    "Type": job.get("type", ""),
                    "Return Code": str(job.get("retcode") or job.get("retCode") or "-"),
                })
            
            st.dataframe(job_data, width="stretch", hide_index=True)
        
        st.markdown("---")
        
        # Datasets Section (from original)
        col1, col2 = st.columns([3, 1])
        with col1:
            st.header("💾 Datasets")
        with col2:
            if st.button("🔄 Refresh Datasets", key="refresh_datasets"):
                opsdash_web.get_datasets.clear()
                opsdash_web.get_pds_members.clear()
                st.rerun()
        
        datasets = opsdash_web.get_datasets(hlq)
        
        if isinstance(datasets, dict) and "error" in datasets:
            st.error(f"❌ Error retrieving datasets: {datasets['error']}")
        elif not datasets:
            st.info(f"No datasets found for {hlq}.*")
        else:
            st.success(f"Found {len(datasets)} dataset(s)")
            
            for dsname in datasets:
                with st.expander(f"📁 {dsname}", expanded=False):
                    with st.spinner(f"Loading members for {dsname}..."):
                        members = opsdash_web.get_pds_members(dsname)
                    
                    if members:
                        st.write(f"**Members ({len(members)}):**")
                        cols = st.columns(min(4, len(members)))
                        for idx, member in enumerate(members[:20]):
                            with cols[idx % len(cols)]:
                                st.code(member, language=None)
                        if len(members) > 20:
                            st.caption(f"... and {len(members) - 20} more")
                    else:
                        st.info("No members found (may not be a PDS or dataset is empty).")
    
    with tab2:
        st.header("💻 COBOL Development")
        st.info("This tab would contain the COBOL editor from the original dashboard.")
        st.warning("To fully enable this, integrate the COBOL development section from opsdash_web.py")
    
    with tab3:
        st.header("📈 Analytics & History")
        
        # Job History Chart
        history = get_recent_job_history(50)
        if history:
            st.subheader("Recent Job Activity")
            
            # Group by status
            status_counts = {}
            for _, _, _, status, _ in history:
                status_counts[status] = status_counts.get(status, 0) + 1
            
            if status_counts:
                st.bar_chart(status_counts)
            
            # Recent jobs table
            st.subheader("Job History Log")
            history_data = []
            for timestamp, job_id, job_name, status, rc in history:
                history_data.append({
                    "Timestamp": timestamp[:19],
                    "Job ID": job_id,
                    "Job Name": job_name,
                    "Status": status,
                    "Return Code": rc,
                })
            
            st.dataframe(history_data, width="stretch", hide_index=True)
        else:
            st.info("No job history available yet. Submit some jobs to see analytics!")
    
    # Footer
    st.markdown("---")
    pi_status = "🍓 Raspberry Pi" if pi_info.get('is_pi') else "💻 Local Machine"
    st.caption(
        f"OpsDash Pi | Running on: {pi_status} | Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )


if __name__ == "__main__":
    main()

