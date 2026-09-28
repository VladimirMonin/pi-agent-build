@echo off
setlocal
set "PI_CODING_AGENT_DIR=%USERPROFILE%\.pi\agent"
set "PI_CBM_MAX_CONCURRENT_INDEXES=1"
set "PI_CBM_AUTO_REFRESH_INTERVAL_MS=300000"
set "CODEBASE_MEMORY_MCP_BIN=%APPDATA%\npm\node_modules\codebase-memory-mcp\bin\codebase-memory-mcp.exe"
call pi %*
