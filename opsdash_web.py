#!/usr/bin/env python3
"""
OpsDash Web - Mainframe Dashboard
A web-based dashboard for z/OS system information, JES jobs, and datasets.
Runs on your local machine and connects via Zowe CLI.
"""

import streamlit as st
import subprocess
import json
import os
import platform
import shutil
import tempfile
from datetime import datetime

# Page config
st.set_page_config(
    page_title="OpsDash - Mainframe Dashboard",
    page_icon="🖥️",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Custom CSS for better styling and disable fade animations
st.markdown(
    """
<style>
    /* Disable Streamlit fade animations */
    .stApp {
        animation: none !important;
    }
    * {
        animation: none !important;
        transition: none !important;
    }
    [data-testid="stAppViewContainer"] {
        animation: none !important;
    }
    .element-container {
        animation: none !important;
    }
    /* Keep only essential transitions for user interactions */
    button:hover {
        transition: background-color 0.2s ease !important;
    }
    
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1f77b4;
        text-align: center;
        margin-bottom: 2rem;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
    .job-active {
        color: #28a745;
        font-weight: bold;
    }
    .job-output {
        color: #ffc107;
    }
</style>
""",
    unsafe_allow_html=True,
)


# Helper functions
def find_zowe_executable():
    """Find Zowe CLI executable, handling Windows PATH issues."""
    # Try to find zowe in PATH
    zowe_path = shutil.which("zowe")
    if zowe_path:
        return zowe_path
    
    # On Windows, try zowe.cmd
    if platform.system() == "Windows":
        zowe_cmd = shutil.which("zowe.cmd")
        if zowe_cmd:
            return zowe_cmd
        
        # Try common npm global install locations
        npm_paths = [
            os.path.join(os.environ.get("APPDATA", ""), "npm", "zowe.cmd"),
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "npm", "zowe.cmd"),
            r"C:\Program Files\nodejs\zowe.cmd",
        ]
        for path in npm_paths:
            if os.path.exists(path):
                return path
    
    return "zowe"  # Fallback to just "zowe" and let subprocess handle the error


def run_zowe_cmd(cmd_list):
    """Run Zowe CLI command and return parsed JSON or error."""
    # Replace "zowe" with the found executable path
    zowe_exe = find_zowe_executable()
    if cmd_list[0] == "zowe":
        cmd_list[0] = zowe_exe
    
    try:
        # On Windows, use shell=True to ensure PATH is properly resolved
        use_shell = platform.system() == "Windows"
        result = subprocess.run(
            cmd_list,
            capture_output=True,
            text=True,
            timeout=30,
            shell=use_shell
        )
        if result.returncode != 0:
            return {"error": result.stderr or result.stdout}

        output = result.stdout.strip()
        if not output:
            return {"error": "Empty response from Zowe CLI"}

        return json.loads(output)
    except FileNotFoundError:
        return {
            "error": "Zowe CLI not found. Please install Zowe CLI and ensure it's in your PATH.\n"
            "Install via: npm install -g @zowe/cli\n"
            "Or download from: https://www.zowe.org/cli.html\n"
            "Then verify with: zowe --version\n\n"
            f"Python tried to find: {zowe_exe}"
        }
    except subprocess.TimeoutExpired:
        return {"error": "Command timed out"}
    except json.JSONDecodeError:
        return {"error": f"Invalid JSON: {result.stdout[:200]}"}
    except Exception as e:
        return {"error": str(e)}


def get_system_info():
    """Get basic system information."""
    return {
        "user": os.environ.get("USER", os.environ.get("USERNAME", "UNKNOWN")),
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "host": "z/OS via Zowe",
    }


def get_user_jobs(user):
    """Get JES jobs for user via Zowe CLI."""
    cmd = ["zowe", "zos-jobs", "list", "jobs", "--owner", user, "--rfj"]
    data = run_zowe_cmd(cmd)

    if "error" in data:
        return data

    # Extract jobs list from Zowe response
    jobs = data.get("data", [])
    if isinstance(jobs, list):
        return jobs
    return []


@st.cache_data(ttl=300)  # Cache for 5 minutes
def get_datasets(hlq):
    """Get datasets for HLQ via Zowe CLI."""
    cmd = ["zowe", "zos-files", "list", "data-set", f"{hlq}.*", "--rfj"]
    data = run_zowe_cmd(cmd)

    if "error" in data:
        return data

    # Extract items from Zowe response
    api = data.get("data", {}).get("apiResponse", {})
    items = api.get("items", [])

    datasets = []
    for item in items:
        dsname = item.get("dsname") or item.get("name")
        if dsname:
            datasets.append(dsname)

    return datasets


@st.cache_data(ttl=300)  # Cache for 5 minutes
def get_pds_members(pds_name):
    """Get members of a PDS via Zowe CLI."""
    cmd = ["zowe", "zos-files", "list", "all-members", pds_name, "--rfj"]
    data = run_zowe_cmd(cmd)

    if "error" in data:
        return []

    api = data.get("data", {}).get("apiResponse", {})
    items = api.get("items", [])

    members = []
    for item in items:
        member = item.get("member") or item.get("memberName")
        if member:
            members.append(member)

    return members


def upload_cobol_to_dataset(dsname, member, content, user_id):
    """Upload COBOL source to a dataset member via Zowe CLI."""
    # Create temporary file with COBOL content
    # Use binary mode and CRLF line endings for z/OS compatibility
    with tempfile.NamedTemporaryFile(mode='wb', suffix='.cbl', delete=False) as f:
        # Convert to bytes and ensure CRLF line endings
        cobol_bytes = content.replace('\r\n', '\n').replace('\r', '\n').replace('\n', '\r\n').encode('utf-8')
        f.write(cobol_bytes)
        temp_path = f.name
    
    try:
        # Upload using Zowe CLI
        cmd = [
            "zowe", "zos-files", "upload", "file-to-data-set",
            temp_path,
            f"{dsname}({member})",
            "--rfj"
        ]
        result = run_zowe_cmd(cmd)
        return result
    finally:
        # Clean up temp file
        if os.path.exists(temp_path):
            os.unlink(temp_path)


def submit_jcl_job(jcl_content, user_id, jcl_member_name=None):
    """Submit a JCL job via Zowe CLI by uploading to dataset first."""
    # Generate unique member name if not provided
    if not jcl_member_name:
        import time
        jcl_member_name = f"TEMP{int(time.time()) % 10000:04d}"[:8]  # Max 8 chars
    
    # Normalize line endings
    jcl_normalized = jcl_content.replace('\r\n', '\n').replace('\r', '\n')
    
    # Create temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.jcl', delete=False, encoding='utf-8', newline='\n') as f:
        f.write(jcl_normalized)
        temp_path = f.name
    
    try:
        # First, upload JCL to a temporary dataset member
        # Use user's JCL dataset
        jcl_ds = f"{user_id}.JCL"
        
        upload_cmd = [
            "zowe", "zos-files", "upload", "file-to-data-set",
            temp_path,
            f"{jcl_ds}({jcl_member_name})",
            "--rfj"
        ]
        
        upload_result = run_zowe_cmd(upload_cmd)
        
        if "error" in upload_result:
            return upload_result
        
        # Now submit from the dataset member
        submit_cmd = [
            "zowe", "zos-jobs", "submit", "data-set",
            f"{jcl_ds}({jcl_member_name})",
            "--rfj"
        ]
        
        result = run_zowe_cmd(submit_cmd)
        return result
    finally:
        # Clean up temp file
        if os.path.exists(temp_path):
            os.unlink(temp_path)


def get_job_status(job_id, user_id):
    """Get status of a JCL job via Zowe CLI."""
    cmd = ["zowe", "zos-jobs", "view", "job-status-by-jobid", job_id, "--rfj"]
    return run_zowe_cmd(cmd)


def get_job_spool_files(job_id, user_id):
    """Get list of all spool files for a job."""
    cmd = ["zowe", "zos-jobs", "list", "spool-files-by-jobid", job_id, "--rfj"]
    return run_zowe_cmd(cmd)


def get_job_spool_file_content(job_id, spool_id, user_id):
    """Get content of a specific spool file."""
    cmd = ["zowe", "zos-jobs", "view", "spool-file-by-id", job_id, str(spool_id), "--rfj"]
    result = run_zowe_cmd(cmd)
    
    if "error" in result:
        return result
    
    # Extract the actual content from Zowe response
    # The content might be in stdout or in a data field
    content = result.get("stdout", "") or result.get("data", {}).get("stdout", "")
    if not content and isinstance(result.get("data"), dict):
        # Try other possible locations
        content = result.get("data", {}).get("content", "") or str(result.get("data", {}))
    
    return {"content": content, "raw": result}


def generate_compile_jcl(user_id, program_name, source_ds, load_ds):
    """Generate a standard COBOL compile and run JCL using IGYWCL procedure."""
    # Ensure program name is exactly 8 chars (pad or truncate)
    job_name = (program_name[:8]).ljust(8)
    pgm_name = program_name[:8]  # Program name max 8 chars
    
    # Build JCL using IGYWCL cataloged procedure (matches working JCL2.jcl format)
    # IGYWCL handles compile and link automatically - much simpler!
    jcl_lines = [
        f"//{job_name} JOB (ACCT),'COMPILE',CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1)",
        f"//*  Compile and run COBOL program {pgm_name}",
        f"//COBRUN  EXEC IGYWCL",
        f"//COBOL.SYSIN  DD DSN={source_ds}({pgm_name}),DISP=SHR",
        f"//LKED.SYSLMOD DD DSN={load_ds}({pgm_name}),DISP=SHR",
        f"//*  Run the compiled program",
        f"//RUN     EXEC PGM={pgm_name}",
        f"//STEPLIB   DD DSN={load_ds},DISP=SHR",
        "//SYSOUT    DD SYSOUT=*",
        "//CEEDUMP   DD DUMMY",
        "//SYSUDUMP  DD DUMMY",
    ]
    
    return '\r\n'.join(jcl_lines)  # Use CRLF explicitly


# Main app
def main():
    # Header
    st.markdown(
        '<p class="main-header">🖥️ OpsDash - Mainframe Dashboard</p>',
        unsafe_allow_html=True,
    )

    # Sidebar configuration
    with st.sidebar:
        st.header("Configuration")
        user_id = st.text_input("User ID", value="Z83570", help="Your z/OS user ID")
        hlq = st.text_input(
            "HLQ (High Level Qualifier)",
            value=user_id.upper(),
            help="Dataset high level qualifier",
        )

        st.markdown("---")
        st.header("About")
        st.info(
            """
        **OpsDash** provides real-time visibility into:
        - System information
        - JES job status
        - Dataset inventory
        - PDS member listings
        
        Data retrieved via Zowe CLI.
        """
        )

    # System Info Section
    st.header("📊 System Summary")
    sys_info = get_system_info()

    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("User", sys_info["user"])
    with col2:
        st.metric("Host", sys_info["host"])
    with col3:
        st.metric("Current Time", sys_info["time"])

    st.markdown("---")

    # Jobs Section
    st.header("📋 JES Jobs")

    with st.spinner("Fetching jobs..."):
        jobs = get_user_jobs(user_id)

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

        # Jobs table
        st.subheader("Job Details")

        # Prepare data for table
        job_data = []
        for job in jobs:
            job_data.append(
                {
                    "Job Name": job.get("jobname") or job.get("jobName", ""),
                    "Job ID": job.get("jobid") or job.get("jobId", ""),
                    "Status": job.get("status", ""),
                    "Owner": job.get("owner", ""),
                    "Type": job.get("type", ""),
                    "Return Code": str(job.get("retcode") or job.get("retCode") or "-"),
                }
            )

        st.dataframe(job_data, width="stretch", hide_index=True)

    st.markdown("---")

    # Datasets Section
    col1, col2 = st.columns([3, 1])
    with col1:
        st.header("💾 Datasets")
    with col2:
        if st.button("🔄 Refresh Datasets", key="refresh_datasets"):
            # Clear cache for datasets and members
            get_datasets.clear()
            get_pds_members.clear()
            st.rerun()

    # Fetch datasets (cached - will be instant on subsequent runs)
    datasets = get_datasets(hlq)

    if isinstance(datasets, dict) and "error" in datasets:
        st.error(f"❌ Error retrieving datasets: {datasets['error']}")
    elif not datasets:
        st.info(f"No datasets found for {hlq}.*")
    else:
        st.success(f"Found {len(datasets)} dataset(s)")

        # Display datasets with expandable members for all PDS datasets
        for dsname in datasets:
            # Try to get members for all datasets (will return empty if not a PDS)
            with st.expander(f"📁 {dsname}", expanded=False):
                with st.spinner(f"Loading members for {dsname}..."):
                    members = get_pds_members(dsname)

                if members:
                    st.write(f"**Members ({len(members)}):**")
                    # Display in columns for better layout
                    cols = st.columns(min(4, len(members)))
                    for idx, member in enumerate(
                        members[:20]
                    ):  # Limit to 20 for performance
                        with cols[idx % len(cols)]:
                            st.code(member, language=None)
                    if len(members) > 20:
                        st.caption(f"... and {len(members) - 20} more")
                else:
                    st.info("No members found (may not be a PDS or dataset is empty).")

    st.markdown("---")

    # COBOL Editor Section
    st.header("💻 COBOL Development")
    st.info("Edit, upload, and run COBOL programs directly from the dashboard.")
    
    st.warning(
        "⚠️ **Note:** If you encounter JCL errors, the generated JCL template uses standard IBM COBOL compiler names. "
        "You may need to adjust dataset names (e.g., `IGY.V6R3M0.SIGYCOMP`) to match your environment. "
        "Check your working JCL from earlier challenges for the correct compiler dataset names."
    )

    tab1, tab2 = st.tabs(["📝 Editor", "📊 Job Status"])

    with tab1:
        st.subheader("COBOL Source Editor")

        col1, col2 = st.columns([2, 1])
        with col1:
            program_name = st.text_input(
                "Program Name",
                value="MYPROG",
                help="Name of the COBOL program (will be used as member name)",
                max_chars=8,
            ).upper()

        with col2:
            source_ds = st.text_input(
                "Source Dataset",
                value=f"{hlq}.SOURCE",
                help="Dataset where COBOL source will be stored",
            )

        # Default COBOL template
        default_cobol = f"""       IDENTIFICATION DIVISION.
       PROGRAM-ID. {program_name}.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-MESSAGE PIC X(50) VALUE 'Hello from OpsDash!'.

       PROCEDURE DIVISION.
           DISPLAY WS-MESSAGE.
           DISPLAY 'Program {program_name} executed successfully.'.
           GOBACK.
"""

        cobol_code = st.text_area(
            "COBOL Source Code",
            value=default_cobol,
            height=300,
            help="Enter or edit your COBOL program source code",
        )

        col1, col2, col3 = st.columns(3)
        with col1:
            if st.button("📤 Upload to Mainframe", type="primary"):
                if not program_name or not cobol_code.strip():
                    st.error("Please enter a program name and COBOL code.")
                else:
                    with st.spinner(f"Uploading {program_name} to {source_ds}..."):
                        result = upload_cobol_to_dataset(
                            source_ds, program_name, cobol_code, user_id
                        )
                        if "error" in result:
                            st.error(f"❌ Upload failed: {result['error']}")
                        else:
                            st.success(
                                f"✅ Successfully uploaded {program_name} to {source_ds}({program_name})"
                            )

        with col2:
            load_ds = st.text_input(
                "Load Dataset",
                value=f"{hlq}.LOAD",
                help="Dataset where compiled program will be stored",
            )

        with col3:
            # Show persistent success messages from session state
            if "cobol_success_msg" in st.session_state:
                st.success(st.session_state["cobol_success_msg"])
                if st.button("✖️ Clear", key="clear_success"):
                    del st.session_state["cobol_success_msg"]
                    st.rerun()
            
            if "cobol_error_msg" in st.session_state:
                st.error(st.session_state["cobol_error_msg"])
                if st.button("✖️ Clear", key="clear_error"):
                    del st.session_state["cobol_error_msg"]
                    st.rerun()
            
            if st.button("🚀 Compile & Run"):
                # Clear old messages
                if "cobol_success_msg" in st.session_state:
                    del st.session_state["cobol_success_msg"]
                if "cobol_error_msg" in st.session_state:
                    del st.session_state["cobol_error_msg"]
                
                if not program_name or not cobol_code.strip():
                    st.session_state["cobol_error_msg"] = "Please enter a program name and COBOL code."
                else:
                    # Step 1: Upload COBOL
                    with st.spinner("Uploading COBOL source..."):
                        upload_result = upload_cobol_to_dataset(
                            source_ds, program_name, cobol_code, user_id
                        )
                        if "error" in upload_result:
                            st.session_state["cobol_error_msg"] = f"❌ Upload failed: {upload_result['error']}"
                        else:
                            # Step 2: Generate and submit JCL
                            with st.spinner("Generating JCL..."):
                                jcl_content = generate_compile_jcl(
                                    user_id, program_name, source_ds, load_ds
                                )

                            # Store JCL in session state for viewing
                            st.session_state["last_jcl_content"] = jcl_content
                            st.session_state["last_jcl_program"] = program_name

                            with st.spinner("Submitting JCL job..."):
                                submit_result = submit_jcl_job(jcl_content, user_id)

                            if "error" in submit_result:
                                st.session_state["cobol_error_msg"] = f"❌ Job submission failed: {submit_result['error']}"
                            else:
                                # Extract job ID from response
                                job_id = (
                                    submit_result.get("data", {})
                                    .get("jobid")
                                    or submit_result.get("jobid")
                                    or "UNKNOWN"
                                )
                                st.session_state["cobol_success_msg"] = f"✅ Job submitted successfully! Job ID: {job_id} - Check 'Job Status' tab to view output."
                                st.session_state["last_job_id"] = job_id
                                st.session_state["last_program"] = program_name
                                # Rerun to update Job Status tab with new job ID
                                st.rerun()
            
            # Show generated JCL if available
            if "last_jcl_content" in st.session_state and "last_jcl_program" in st.session_state:
                with st.expander(f"📄 View Generated JCL for {st.session_state['last_jcl_program']}", expanded=False):
                    st.code(st.session_state["last_jcl_content"], language=None)

    with tab2:
        st.subheader("Job Status & Output")

        # Check for last submitted job
        if "last_job_id" in st.session_state:
            default_job_id = st.session_state["last_job_id"]
        else:
            default_job_id = ""
        
        job_id = st.text_input(
            "Job ID",
            value=default_job_id,
            help="Enter a job ID to check status",
            key="job_status_input"
        )

        # Store job status in session state to persist across reruns
        status_key = f"job_status_{job_id}"
        spool_key = f"job_spool_{job_id}"
        
        # Track which job we're currently viewing
        current_viewing_key = "current_viewing_job"
        
        # Clear status if job ID changed
        if current_viewing_key in st.session_state:
            if st.session_state[current_viewing_key] != job_id:
                # Job ID changed, clear old data
                old_job = st.session_state[current_viewing_key]
                old_status_key = f"job_status_{old_job}"
                old_spool_key = f"job_spool_{old_job}"
                if old_status_key in st.session_state:
                    del st.session_state[old_status_key]
                if old_spool_key in st.session_state:
                    del st.session_state[old_spool_key]

        if job_id and st.button("🔍 Check Job Status", key="check_status_btn"):
            st.session_state[current_viewing_key] = job_id
            with st.spinner(f"Checking status of job {job_id}..."):
                status = get_job_status(job_id, user_id)
                st.session_state[status_key] = status
                # Clear old spool files when checking new job
                if spool_key in st.session_state:
                    del st.session_state[spool_key]

        # Display stored status if available
        if status_key in st.session_state:
            status = st.session_state[status_key]
            
            if "error" in status:
                st.error(f"❌ Error: {status['error']}")
            else:
                job_data = status.get("data", status)
                
                # Show key info in a nice format
                if isinstance(job_data, dict):
                    col1, col2, col3, col4 = st.columns(4)
                    with col1:
                        st.metric("Status", job_data.get('status', 'UNKNOWN'))
                    with col2:
                        st.metric("Job Name", job_data.get('jobname', job_data.get('jobName', 'N/A')))
                    with col3:
                        rc = job_data.get('retcode', job_data.get('retCode', 'N/A'))
                        st.metric("Return Code", str(rc))
                    with col4:
                        st.metric("Owner", job_data.get('owner', 'N/A'))

                    st.markdown("---")
                    
                    # Get and display spool files (use cached if available)
                    if spool_key not in st.session_state:
                        with st.spinner("Loading spool files..."):
                            spool_files = get_job_spool_files(job_id, user_id)
                            st.session_state[spool_key] = spool_files
                    else:
                        spool_files = st.session_state[spool_key]
                    
                    if "error" in spool_files:
                        st.warning(f"Could not retrieve spool files: {spool_files['error']}")
                    else:
                        # Extract spool file list
                        spool_list = spool_files.get("data", [])
                        if not spool_list and isinstance(spool_files, list):
                            spool_list = spool_files
                        
                        if spool_list:
                            st.subheader("📄 Spool Files")
                            
                            # Store loaded content keys
                            content_key_base = f"spool_content_{job_id}_"
                            
                            # Create tabs for each spool file or a selector
                            if len(spool_list) <= 5:
                                # Show all spool files in tabs if few
                                tabs = st.tabs([f"{s.get('ddname', s.get('stepname', 'Unknown'))}" for s in spool_list[:5]])
                                for idx, tab in enumerate(tabs):
                                    with tab:
                                        spool = spool_list[idx]
                                        spool_id = spool.get('id', spool.get('stepname', '2'))
                                        ddname = spool.get('ddname', spool.get('procstep', 'Unknown'))
                                        
                                        st.write(f"**DD Name:** {ddname}")
                                        st.write(f"**Spool ID:** {spool_id}")
                                        
                                        content_key = f"{content_key_base}{spool_id}"
                                        
                                        # Load button
                                        if content_key not in st.session_state:
                                            if st.button(f"📄 Load Content", key=f"load_{job_id}_{spool_id}"):
                                                with st.spinner(f"Loading {ddname}..."):
                                                    content_result = get_job_spool_file_content(job_id, spool_id, user_id)
                                                
                                                if "error" in content_result:
                                                    st.error(f"Error: {content_result['error']}")
                                                else:
                                                    content = content_result.get("content", "")
                                                    st.session_state[content_key] = content
                                        else:
                                            # Show loaded content
                                            st.text_area(
                                                f"Content of {ddname}",
                                                value=st.session_state[content_key],
                                                height=400,
                                                key=f"display_{job_id}_{spool_id}"
                                            )
                                            if st.button(f"🔄 Reload", key=f"reload_{job_id}_{spool_id}"):
                                                del st.session_state[content_key]
                            else:
                                # Too many spool files - use a selector
                                spool_options = {
                                    f"{s.get('ddname', s.get('stepname', 'Unknown'))} (ID: {s.get('id', '?')})": s.get('id', s.get('stepname', '2'))
                                    for s in spool_list
                                }
                                
                                selected_spool = st.selectbox(
                                    "Select Spool File to View:",
                                    options=list(spool_options.keys()),
                                    key=f"spool_select_{job_id}"
                                )
                                
                                spool_id = spool_options[selected_spool]
                                content_key = f"{content_key_base}{spool_id}"
                                
                                if st.button("📄 View Selected Spool File", key=f"view_{job_id}_{spool_id}"):
                                    with st.spinner("Loading spool file content..."):
                                        content_result = get_job_spool_file_content(job_id, spool_id, user_id)
                                    
                                    if "error" in content_result:
                                        st.error(f"Error: {content_result['error']}")
                                    else:
                                        content = content_result.get("content", "")
                                        st.session_state[content_key] = content
                                
                                # Show content if loaded
                                if content_key in st.session_state:
                                    st.text_area(
                                        "Spool File Content",
                                        value=st.session_state[content_key],
                                        height=400,
                                        key=f"display_{job_id}_{spool_id}"
                                    )
                        else:
                            st.info("No spool files found for this job.")

    # Footer
    st.markdown("---")
    st.caption(
        f"OpsDash Web | Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )


if __name__ == "__main__":
    main()
